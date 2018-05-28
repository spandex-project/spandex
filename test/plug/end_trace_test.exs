defmodule Spandex.Plug.EndTraceTest do
  use ExUnit.Case

  alias Spandex.Plug.EndTrace
  alias Spandex.Plug.Utils

  setup do
    {:ok, trace_id} = Spandex.start_trace("request")

    {
      :ok,
      [
        trace_id: trace_id,
        conn: Plug.Adapters.Test.Conn.conn(%Plug.Conn{}, :get, "/dashboard", nil)
      ]
    }
  end

  describe "EndTrace.call/2" do
    test "doesn't finish trace, when we don't trace request", %{conn: conn, trace_id: tid} do
      %Plug.Conn{} = EndTrace.call(conn, [])

      assert Spandex.current_trace_id() == tid

      :ok = Spandex.finish_trace()
    end

    test "updates top span and finish span, when we trace request for 200", %{
      conn: conn,
      trace_id: tid
    } do
      %Plug.Conn{} =
        conn
        |> Plug.Conn.put_status(:ok)
        |> Utils.trace(true)
        |> EndTrace.call([])

      assert is_nil(Spandex.current_trace_id())

      {:error, :no_trace_context} = Spandex.finish_trace()

      %{trace_id: trace_id, meta: meta, error: error} = Spandex.Test.Util.find_span("request")

      assert trace_id == tid
      assert Map.get(meta, "http.status_code") == "200"
      assert error == 0
    end

    test "updates top span and finish span, when we trace request for 404", %{
      conn: conn,
      trace_id: tid
    } do
      %Plug.Conn{} =
        conn
        |> Plug.Conn.put_status(:not_found)
        |> Utils.trace(true)
        |> EndTrace.call([])

      assert is_nil(Spandex.current_trace_id())

      {:error, :no_trace_context} = Spandex.finish_trace()

      %{trace_id: trace_id, meta: meta, error: error} = Spandex.Test.Util.find_span("request")

      assert trace_id == tid
      assert Map.get(meta, "http.status_code") == "404"
      assert error == 1
    end
  end
end
