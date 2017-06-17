defmodule Spandex.Plug.AddContext do
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    if Confex.get(:spandex, :disabled?) do
      conn
    else
      adapter = Confex.get(:spandex, :adapter)

      trace_context = %{
        resource: "#{String.upcase(conn.method)} #{route_name(conn)}",
        method: conn.method,
        url: conn.request_path,
        service: Confex.get(:spandex, :primary_service, :web),
        type: :web
      }

      _ = adapter.update_span(trace_context, true)

      _ = Logger.metadata(trace_id: adapter.current_trace_id(), span_id: adapter.current_span_id())

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
