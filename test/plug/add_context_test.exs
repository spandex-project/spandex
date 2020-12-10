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

      {:ok, _} = Tracer.finish_trace()

      %{resource: resource, http: http} = Spandex.Test.Util.find_span("request")

      assert is_nil(http[:url])
      assert is_nil(http[:method])
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

      assert {:ok, expected_span} = Tracer.start_span("foobar")

      assert Keyword.fetch!(Logger.metadata(), :trace_id) == to_string(tid)
      assert Keyword.fetch!(Logger.metadata(), :span_id) == to_string(expected_span.id)

      {:ok, _} = Tracer.finish_trace()

      %{trace_id: trace_id, type: type, http: http, resource: resource} = Spandex.Test.Util.find_span("request")

      assert trace_id == tid
      assert type == :web
      assert http[:url] == "/dashboard"
      assert http[:method] == "GET"
      assert resource == "GET /dashboard"
    end
  end
end
