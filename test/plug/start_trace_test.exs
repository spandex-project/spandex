defmodule Spandex.Plug.StartTraceTest do
  use ExUnit.Case

  alias Spandex.Plug.StartTrace

  def gen_conn(method, path),
    do: Plug.Adapters.Test.Conn.conn(%Plug.Conn{}, method, path, nil)

  def with_conf(app, key, val, fun),
    do: with_conf(app, key, val, Application.get_env(app, key), fun)

  def with_conf(app, key, new_val, old_val, fun) do
    Application.put_env app, key, new_val
    fun.()
  after
    Application.put_env app, key, old_val
  end

  setup_all do
    {:ok, [conn: gen_conn(:get, "/dashboard")]}
  end

  describe "StartTrace.call/2" do
    test "doesn't create a trace, when Spandex is disabled", %{conn: conn} do
      with_conf :spandex, :disabled?, true, fn ->
        new_conn = StartTrace.call(conn, [])
        assert is_nil(Spandex.current_trace_id())
        refute new_conn.assigns[:spandex_trace_request?]
      end
    end

    test "doesn't create a trace, when method is configured as ignored", %{conn: conn} do
      with_conf :spandex, :ignored_methods, ["GET", "POST"], fn ->
        refute Spandex.disabled?()

        new_conn = StartTrace.call(conn, [])
        assert is_nil(Spandex.current_trace_id())
        refute new_conn.assigns[:spandex_trace_request?]

        new_conn = StartTrace.call(gen_conn(:post, "/foo"), [])
        assert is_nil(Spandex.current_trace_id())
        refute new_conn.assigns[:spandex_trace_request?]
      end
    end

    test "doesn't create a trace, when path is marked as ignored with regex", %{conn: conn} do
      with_conf :spandex, :ignored_routes, [~r|/dashboard|, ~r|/users/\d+/edit|], fn ->
        refute Spandex.disabled?()

        new_conn = StartTrace.call(conn, [])
        assert is_nil(Spandex.current_trace_id())
        refute new_conn.assigns[:spandex_trace_request?]

        new_conn = StartTrace.call(gen_conn(:post, "/users/23/edit"), [])
        assert is_nil(Spandex.current_trace_id())
        refute new_conn.assigns[:spandex_trace_request?]
      end
    end

    test "doesn't create a trace, when path is marked as ignored with exact match", %{conn: conn} do
      with_conf :spandex, :ignored_routes, ["/foobars", "/dashboard"], fn ->
        refute Spandex.disabled?()

        new_conn = StartTrace.call(conn, [])

        assert is_nil(Spandex.current_trace_id())
        refute new_conn.assigns[:spandex_trace_request?]
        new_conn = StartTrace.call(gen_conn(:get, "/foobars"), [])
        assert is_nil(Spandex.current_trace_id())
        refute new_conn.assigns[:spandex_trace_request?]
      end
    end

    test "continues existing trace when distributed context exists", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("x-datadog-trace-id", "12345")
        |> Plug.Conn.put_req_header("x-datadog-parent-id", "67890")

      new_conn = StartTrace.call(conn, [])

      assert %{trace_id: "12345", parent_id: "67890"} = Spandex.current_span()

      refute Spandex.current_span_id() == "67890"
      refute is_nil(Spandex.current_span_id())

      assert new_conn.assigns[:spandex_trace_request?]
    end

    test "starts new trace", %{conn: conn} do
      new_conn = StartTrace.call(conn, [])

      refute is_nil(Spandex.current_trace_id())
      assert new_conn.assigns[:spandex_trace_request?]
    end
  end
end
