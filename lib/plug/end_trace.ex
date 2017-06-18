defmodule Spandex.Plug.EndTrace do
  @moduledoc """
  Finishes a trace, setting status and error based on the HTTP status.
  """
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    end_trace(conn)
  end

  def end_trace(conn) do
    _ = update_trace_with_conn_status(conn)

    _ = Spandex.finish_trace()

    conn
  end

  defp update_trace_with_conn_status(%{status: status}) when status in 200..399 do
    Spandex.update_top_span(%{status: status, error: 0})
  end

  defp update_trace_with_conn_status(%{status: status}) do
    Spandex.update_top_span(%{status: status, error: 1})
  end
end
