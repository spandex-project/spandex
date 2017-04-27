defmodule Spandex.Plug.EndTrace do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    end_trace(conn)
  end

  def end_trace(conn) do
    unless Application.get_env(:spandex, :disabled?) do
      _ = update_trace_with_conn_status(conn)
      _ = Spandex.Trace.publish()
      _ = :ets.delete(:spandex_trace, self())
    end

    conn
  end

  defp update_trace_with_conn_status(%{status: status}) when status in 200..399 do
    Spandex.Trace.update_top_level_span(%{status: status, error: 0})
  end

  defp update_trace_with_conn_status(%{status: status}) do
    Spandex.Trace.update_top_level_span(%{status: status, error: 1})
  end
end
