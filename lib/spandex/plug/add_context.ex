defmodule Spandex.Plug.AddContext do
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    if Application.get_env(:spandex, :disabled?) do
      conn
    else
      trace_context = %{
        resource: "#{String.upcase(conn.method)} #{route_name(conn)}",
        method: conn.method,
        url: conn.request_path,
        service: Application.get_env(:spandex, :service, :web),
        type: :web
      }

      Spandex.Trace.update_all_spans(trace_context)

      Plug.Conn.assign(:trace_context, trace_context)
    end
  end

  @spec trace_context(Plug.Conn.t) :: map
  def trace_context(conn) do
    conn.assigns[:trace_context] || %{}
  end

  @spec update_from_trace_context(Plug.Conn.t) :: Plug.Conn.t
  def update_from_trace_context(conn) do
    conn
    |> trace_context
    |> Spandex.Trace.update_span
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
