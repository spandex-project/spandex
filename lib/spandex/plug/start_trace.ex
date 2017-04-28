defmodule Spandex.Plug.StartTrace do
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(config_override), do: config_override

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, opts) do
    unless ignoring_request?(conn) do
      case Spandex.Trace.start(opts) do
        {:ok, pid} ->
          :ets.insert(:spandex_trace, {self(), pid})
        _ -> :error
      end
    end

    conn
  end

  defp ignoring_request?(conn) do
    disabled?() || ignored_method?(conn) || ignored_route?(conn)
  end

  defp disabled?() do
    !!Application.get_env(:spandex, :disabled?)
  end

  defp ignored_method?(conn) do
    ignored_methods = Application.get_env(:spandex, :ignored_methods, [])
    conn.method in ignored_methods
  end

  defp ignored_route?(conn) do
    ignored_routes = Application.get_env(:spandex, :ignored_routes, [])
    Enum.any?(ignored_routes, fn ignored_route ->
      String.match?(conn.request_path, ignored_route)
    end)
  end

end
