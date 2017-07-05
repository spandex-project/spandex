defmodule Spandex.Plug.StartTrace do
  @moduledoc """
  Starts a trace, skipping ignored routes or methods.
  Store info in Conn assigns if we actually trace the request.
  """
  @behaviour Plug

  @spec init(opts :: Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(conn :: Plug.Conn.t, _opts :: Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    if ignoring_request?(conn) do
      trace(conn, false)
    else
      Spandex.start_trace("request")
      trace(conn, true)
    end
  end

  @spec ignoring_request?(conn :: Plug.Conn.t) :: boolean
  defp ignoring_request?(conn) do
    disabled?() || ignored_method?(conn) || ignored_route?(conn)
  end

  @spec disabled?() :: boolean
  defp disabled?,
    do: Spandex.disabled?()

  @spec ignored_method?(conn :: Plug.Conn.t) :: boolean
  defp ignored_method?(conn) do
    ignored_methods = Confex.get_env(:spandex, :ignored_methods, [])
    conn.method in ignored_methods
  end

  @spec ignored_route?(conn :: Plug.Conn.t) :: boolean
  defp ignored_route?(conn) do
    ignored_routes = Confex.get_env(:spandex, :ignored_routes, [])
    Enum.any?(ignored_routes, fn ignored_route ->
      String.match?(conn.request_path, ignored_route)
    end)
  end

  @spec trace(conn :: Plug.Conn.t, trace? :: boolean) :: Plug.Conn.t
  def trace(conn, trace?),
    do: Plug.Conn.assign(conn, :spandex_trace_request?, trace?)
end
