defmodule Spandex.Plug.AddContext do
  @moduledoc """
  Adds request context to the top span of the trace, setting
  the resource, method, url, service, type and env
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @spec init(opts :: Keyword.t) :: Keyword.t
  def init(opts) do
    opts
    |> Keyword.update(:allowed_route_replacements, nil, fn config -> Enum.map(config, &Atom.to_string/1) end)
    |> Keyword.update(:disallowed_route_replacements, [], fn config -> Enum.map(config, &Atom.to_string/1) end)
    |> Keyword.update(:query_params, [], fn config -> Enum.map(config || [], &Atom.to_string/1) end)
    |> Keyword.take([:allowed_route_replacements, :disallowed_route_replacements, :query_params])
  end

  @spec call(conn :: Plug.Conn.t, _opts :: Keyword.t) :: Plug.Conn.t
  def call(conn, opts) do
    if Utils.trace?(conn) do
      conn = Plug.Conn.fetch_query_params(conn)
      replacement_params =
        if opts[:allowed_route_replacements] do
          conn.params
          |> Map.take(opts[:allowed_route_replacements])
          |> Map.drop(opts[:disallowed_route_replacements])
        else
          Map.drop(conn.params, opts[:disallowed_route_replacements])
        end

      route =
        conn
        |> Map.put(:params, replacement_params)
        |> route_name()
        |> add_query_params(conn.params, opts[:query_params])

      Spandex.update_top_span(%{
        resource: route,
        name: route,
        method: conn.method,
        url: conn.request_path,
        type: :web,
      })

      trace_id =
        case Spandex.current_trace_id() do
          {:error, _error} -> nil
          trace_id -> trace_id
        end

      span_id =
        case Spandex.current_span_id() do
          {:error, _error} -> nil
          span_id -> span_id
        end

      Logger.metadata(trace_id: trace_id, span_id: span_id)

      conn
    else
      conn
    end
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

  @spec add_query_params(String.t(), map() | nil, [String.t()] | nil) :: String.t()
  defp add_query_params(uri, _, []), do: uri
  defp add_query_params(uri, _, nil), do: uri
  defp add_query_params(uri, nil, _), do: uri
  defp add_query_params(uri, params, take) do
    to_encode = Map.take(params, take |> IO.inspect()) |> IO.inspect()

    uri <> "?" <> Plug.Conn.Query.encode(to_encode) |> IO.inspect()
  end
end
