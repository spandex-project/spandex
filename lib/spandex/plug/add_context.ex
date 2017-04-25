defmodule Spandex.Plug.AddContext do
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    unless Application.get_env(:spandex, :disabled?) do
      Spandex.Trace.update_all_spans(
        %{
          resource: route_name(conn),
          method: conn.method,
          url: conn.request_path,
          service: Application.get_env(:spandex, :service, "spandex"),
          type: "web"
        }
      )
    end

    conn
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
