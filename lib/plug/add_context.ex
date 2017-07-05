defmodule Spandex.Plug.AddContext do
  @moduledoc """
  Adds request context to the top span of the trace, setting
  the resource, method, url, service, type and env
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @spec init(opts :: Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(conn :: Plug.Conn.t, _opts :: Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    if Utils.trace?(conn) do
      route =
        conn
        |> Plug.Conn.fetch_query_params()
        |> route_name()

      %{
        resource: "#{String.upcase(conn.method)} #{route}",
        method: conn.method,
        url: conn.request_path,
        type: :web,
      }
      |> Spandex.update_top_span()

      Logger.metadata(trace_id: Spandex.current_trace_id(), span_id: Spandex.current_span_id())
    end

    conn
  end

  @spec route_name(Plug.Conn.t) :: String.t
  defp route_name(%Plug.Conn{path_info: path_values, params: params}) do
    inverted_params = Enum.into(params, %{}, fn {key, value} -> {value, key} end)

    Enum.map_join(path_values, "/", fn path_part ->
      if Map.has_key?(inverted_params, path_part)  do
        ":#{inverted_params[path_part]}"
      else
        path_part
      end
    end)
  end
end
