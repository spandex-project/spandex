defmodule Spandex.Plug.AddContext do
  @moduledoc """
  Adds request context to the top span of the trace, setting
  the resource, method, url, service, type and env
  """
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    if Confex.get(:spandex, :disabled?) do
      conn
    else
      trace_context = %{
        resource: "#{String.upcase(conn.method)} #{route_name(conn)}",
        method: conn.method,
        url: conn.request_path,
        service: Confex.get(:spandex, :service, :web),
        type: :web,
        env: Confex.get(:spandex, :env, "unknown")
      }

      _ = Spandex.update_top_span(trace_context)

      _ = Logger.metadata(trace_id: Spandex.current_trace_id(), span_id: Spandex.current_span_id())

      conn
    end
  end

  @spec route_name(Plug.Conn.t) :: String.t
  defp route_name(%{path_info: path_values, params: params}) do
    inverted_params = Enum.into(params, %{}, fn {key, value} -> {value, key} end)

    path_values
    |> Enum.map(fn path_part ->
      if Map.has_key?(inverted_params, path_part)  do
        ":#{inverted_params[path_part]}"
      else
        path_part
      end
    end)
    |> Enum.join("/")
  end
end
