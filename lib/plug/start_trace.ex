defmodule Spandex.Plug.StartTrace do
  @moduledoc """
  Starts a trace, skipping ignored routes or methods.
  """
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    _ =
      unless ignoring_request?(conn) do
        Spandex.start_trace("request")
      end

    conn
  end

  @spec ignoring_request?(Plug.Conn.t) :: boolean
  defp ignoring_request?(conn) do
    disabled?() || ignored_method?(conn) || ignored_route?(conn)
  end

  @spec disabled?() :: boolean
  defp disabled?() do
    Spandex.disabled?()
  end

  @spec ignored_method?(Plug.Conn.t) :: boolean
  defp ignored_method?(conn) do
    ignored_methods = Confex.get_env(:spandex, :ignored_methods, [])
    conn.method in ignored_methods
  end

  @spec ignored_route?(Plug.Conn.t) :: boolean
  defp ignored_route?(conn) do
    ignored_routes = Confex.get_env(:spandex, :ignored_routes, [])
    Enum.any?(ignored_routes, fn ignored_route ->
      String.match?(conn.request_path, ignored_route)
    end)
  end

end
