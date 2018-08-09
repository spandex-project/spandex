defmodule Spandex.Plug.StartTraceTest do
  use ExUnit.Case

  alias Spandex.Plug.StartTrace
  alias Spandex.Test.Support.Tracer

  def gen_conn(method, path),
    do: Plug.Adapters.Test.Conn.conn(%Plug.Conn{}, method, path, nil)

  setup_all do
    {:ok, [conn: gen_conn(:get, "/dashboard")]}
  end

  describe "StartTrace.call/2" do
    test "doesn't create a trace, when Spandex is disabled", %{conn: conn} do
      new_conn =
        StartTrace.call(
          conn,
          ignored_routes: [],
          ignored_methods: [],
          tracer: Tracer,
          tracer_opts: [disabled?: true]
        )

      assert is_nil(Tracer.current_trace_id())
      refute new_conn.assigns[:spandex_trace_request?]
    end

    test "doesn't create a trace, when method is configured as ignored", %{conn: conn} do
      new_conn = StartTrace.call(conn, ignored_routes: [], ignored_methods: ["GET", "POST"])
      assert is_nil(Tracer.current_trace_id())
      refute new_conn.assigns[:spandex_trace_request?]

      new_conn =
        StartTrace.call(
          gen_conn(:post, "/foo"),
          ignored_routes: [],
          ignored_methods: ["GET", "POST"],
          tracer: Tracer
        )

      assert is_nil(Tracer.current_trace_id())
      refute new_conn.assigns[:spandex_trace_request?]
    end

    test "doesn't create a trace, when path is marked as ignored with regex", %{conn: conn} do
      new_conn =
        StartTrace.call(
          conn,
          ignored_routes: [~r|/dashboard|, ~r|/users/\d+/edit|],
          ignored_methods: [],
          tracer: Tracer
        )

      assert is_nil(Tracer.current_trace_id())
      refute new_conn.assigns[:spandex_trace_request?]

      new_conn =
        StartTrace.call(
          gen_conn(:post, "/users/23/edit"),
          ignored_routes: [~r|/dashboard|, ~r|/users/\d+/edit|],
          ignored_methods: [],
          tracer: Tracer
        )

      assert is_nil(Tracer.current_trace_id())
      refute new_conn.assigns[:spandex_trace_request?]
    end

    test "doesn't create a trace, when path is marked as ignored with exact match", %{conn: conn} do
      new_conn =
        StartTrace.call(
          conn,
          ignored_routes: ["/foobars", "/dashboard"],
          ignored_methods: [],
          tracer: Tracer
        )

      assert is_nil(Tracer.current_trace_id())
      refute new_conn.assigns[:spandex_trace_request?]

      new_conn =
        StartTrace.call(
          gen_conn(:get, "/foobars"),
          ignored_routes: ["/foobars", "/dashboard"],
          ignored_methods: [],
          tracer: Tracer
        )

      assert is_nil(Tracer.current_trace_id())
      refute new_conn.assigns[:spandex_trace_request?]
    end

    test "continues existing trace when distributed context exists", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("x-test-trace-id", "12345")
        |> Plug.Conn.put_req_header("x-test-parent-id", "67890")

      new_conn = StartTrace.call(conn, ignored_routes: [], ignored_methods: [], tracer: Tracer)

      assert %{trace_id: 12_345, parent_id: 67_890} = Tracer.current_span()

      refute Tracer.current_span_id() == 67_890
      refute is_nil(Tracer.current_span_id())

      assert new_conn.assigns[:spandex_trace_request?]
    end

    test "starts new trace", %{conn: conn} do
      new_conn =
        StartTrace.call(
          conn,
          ignored_routes: [],
          ignored_methods: [],
          tracer: Tracer,
          span_name: "request"
        )

      refute is_nil(Tracer.current_trace_id())
      assert new_conn.assigns[:spandex_trace_request?]
    end
  end
end
