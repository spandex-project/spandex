defmodule Spandex.Plug.StartTrace do
  @moduledoc """
  Starts a trace, skipping ignored routes or methods.
  Store info in Conn assigns if we actually trace the request.
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @spec init(opts :: Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(conn :: Plug.Conn.t, _opts :: Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    if ignoring_request?(conn) do
      Utils.trace(conn, false)
    else
      begin_tracing(conn)
    end
  end

  @spec begin_tracing(conn :: Plug.Conn.t) :: Plug.Conn.t
  defp begin_tracing(conn) do
    case Spandex.distributed_context(conn) do
      {:ok, %{trace_id: trace_id, parent_id: parent_id}} ->
        Spandex.continue_trace("request", trace_id, parent_id)

      {:error, :no_distributed_trace} ->
        Spandex.start_trace("request", %{level: Spandex.highest_level()})
    end

    Utils.trace(conn, true)
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
      match_route?(conn.request_path, ignored_route)
    end)
  end

  @spec match_route?(route :: String.t, ignore :: %Regex{} | String.t) :: boolean
  defp match_route?(ignore, ignore) when is_bitstring(ignore), do: true
  defp match_route?(_, ignore) when is_bitstring(ignore), do: false
  defp match_route?(route, ignore) do
    String.match?(route, ignore)
  end
end
