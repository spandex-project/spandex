defmodule Spandex.Plug.AddContextTest do
  use ExUnit.Case

  alias Spandex.Plug.AddContext
  alias Spandex.Plug.Utils
  alias Spandex.Test.Support.Tracer

  setup do
    {:ok, trace} = Tracer.start_trace("request")

    {
      :ok,
      [
        trace_id: trace.id,
        conn: Plug.Adapters.Test.Conn.conn(%Plug.Conn{}, :get, "/dashboard", nil)
      ]
    }
  end

  describe "AddContext.call/2" do
    test "doesn't change anything, when we don't trace request", %{conn: conn} do
      %Plug.Conn{} =
        AddContext.call(
          conn,
          allowed_route_replacements: nil,
          disallowed_route_replacements: [],
          tracer: Tracer,
          tracer_opts: []
        )

      :ok = Tracer.finish_trace()

      %{resource: resource, meta: meta} = Spandex.Test.Util.find_span("request")

      assert is_nil(Map.get(meta, "http.url"))
      assert is_nil(Map.get(meta, "http.method"))
      assert resource == "default"
    end

    test "updates top span and logger, when we trace request", %{conn: conn, trace_id: tid} do
      %Plug.Conn{} =
        conn
        |> Utils.trace(true)
        |> AddContext.call(
          allowed_route_replacements: nil,
          disallowed_route_replacements: [],
          tracer: Tracer,
          tracer_opts: []
        )

      {:ok, expected_span} = Tracer.start_span("foobar")

      assert Keyword.fetch!(Logger.metadata(), :trace_id) == tid
      assert Keyword.fetch!(Logger.metadata(), :span_id) == expected_span.id

      :ok = Tracer.finish_trace()

      %{trace_id: trace_id, type: type, meta: meta, resource: resource} =
        Spandex.Test.Util.find_span("request")

      assert trace_id == tid
      assert type == :web
      assert Map.get(meta, "http.url") == "/dashboard"
      assert Map.get(meta, "http.method") == "GET"
      assert resource == "GET /dashboard"
    end
  end
end
