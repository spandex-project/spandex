defmodule Spandex.Plug.EndTrace do
  @moduledoc """
  Finishes a trace, setting status and error based on the HTTP status.
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @spec init(opts :: Keyword.t()) :: Keyword.t()
  def init(opts), do: opts

  @spec call(conn :: Plug.Conn.t(), _opts :: Keyword.t()) :: Plug.Conn.t()
  def call(conn, _opts) do
    if Utils.trace?(conn) do
      Spandex.update_top_span(%{
        status: conn.status,
        error: error_count(conn)
      })

      Spandex.finish_trace()
    end

    conn
  end

  defp error_count(%{status: status}) when status in 200..399,
    do: 0

  defp error_count(%{status: _status}),
    do: 1
end
