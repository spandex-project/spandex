defmodule Spandex.Plug.StartTrace do
  @moduledoc """
  Starts a trace, skipping ignored routes or methods.
  """
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    unless ignoring_request?(conn) do
      adapter = Confex.get(:spandex, :adapter)

      _ = adapter.start_trace("request")
    end

    conn
  end

  defp ignoring_request?(conn) do
    disabled?() || ignored_method?(conn) || ignored_route?(conn)
  end

  defp disabled?() do
    Confex.get(:spandex, :disabled?)
  end

  defp ignored_method?(conn) do
    ignored_methods = Confex.get(:spandex, :ignored_methods, [])
    conn.method in ignored_methods
  end

  defp ignored_route?(conn) do
    ignored_routes = Confex.get(:spandex, :ignored_routes, [])
    Enum.any?(ignored_routes, fn ignored_route ->
      String.match?(conn.request_path, ignored_route)
    end)
  end

end
