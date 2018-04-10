defmodule Spandex.Plug.EndTrace do
  @moduledoc """
  Finishes a trace, setting status and error based on the HTTP status.
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @spec init(opts :: Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(conn :: Plug.Conn.t, _opts :: Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    if Utils.trace?(conn) do
      set_error(conn)
      Spandex.update_top_span(%{"http.status_code": conn.status, meta: %{"http.status_code": conn.status}})

      Spandex.finish_trace()
    end

    conn
  end

  @spec set_error(Plug.Conn.t()) :: :ok
  defp set_error(%{status: status}) when status in 200..399 do
    :ok
  end
  defp set_error(%{status: _status}) do
    Spandex.span_error()
    :ok
  end
end
