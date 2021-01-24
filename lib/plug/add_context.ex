defmodule Spandex.Plug.AddContext do
  @moduledoc """
  Adds request context to the top span of the trace, setting
  the resource, method, url, service, type and env.

  ## Options

  This plug accepts the following options:

    * `:tracer` - The tracing module to be used to start the trace. Required.
    * `:allowed_route_replacements` - A list of route parts that may be replaced with their actual value.
      If not set or set to nil, then all will be allowed, unless they are disallowed.
    * `:disallowed_route_replacements` - A list of route parts that may *not* be replaced with their actual value.
    * `:query_params` - A list of query params who's value will be included in the resource name.
    * `:tracer_opts` - Any opts to be passed to the tracer when starting or continuing the trace.
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @default_opts [
    allowed_route_replacements: nil,
    disallowed_route_replacements: [],
    query_params: [],
    tracer_opts: []
  ]

  @doc """
  Starts a trace, considering the filters/parameters in the provided options.

  You would generally not use `allowed_route_replacements` and `disallowed_route_replacements` together.
  """
  @spec init(opts :: Keyword.t()) :: Keyword.t()
  def init(opts) do
    @default_opts
    |> Keyword.merge(opts || [])
    |> Keyword.update!(:allowed_route_replacements, fn config ->
      if config do
        Enum.map(config, &Atom.to_string/1)
      else
        config
      end
    end)
    |> Keyword.update!(:disallowed_route_replacements, fn config ->
      Enum.map(config, &Atom.to_string/1)
    end)
    |> Keyword.update!(:query_params, fn config ->
      Enum.map(config || [], &Atom.to_string/1)
    end)
  end

  @spec call(conn :: Plug.Conn.t(), _opts :: Keyword.t()) :: Plug.Conn.t()
  def call(conn, opts) do
    tracer = opts[:tracer]
    tracer_opts = opts[:tracer_opts]

    if Utils.trace?(conn) do
      conn = Plug.Conn.fetch_query_params(conn)

      params =
        if opts[:allowed_route_replacements] do
          conn.params
          |> Map.take(opts[:allowed_route_replacements])
          |> Map.drop(opts[:disallowed_route_replacements])
        else
          Map.drop(conn.params, opts[:disallowed_route_replacements])
        end

      route =
        conn
        |> Map.put(:params, params)
        |> route_name()
        |> add_query_params(conn.params, opts[:query_params])
        |> URI.decode_www_form()

      user_agent =
        conn
        |> Plug.Conn.get_req_header("user-agent")
        |> List.first()

      opts =
        Keyword.merge(
          [
            resource: String.upcase(conn.method) <> " /" <> route,
            http: [
              method: conn.method,
              url: conn.request_path,
              query_string: conn.query_string,
              user_agent: user_agent
            ],
            type: :web
          ],
          tracer_opts
        )

      tracer.update_top_span(opts)

      conn
    else
      conn
    end
  end

  @spec route_name(Plug.Conn.t()) :: String.t()
  defp route_name(%Plug.Conn{path_info: path_values, params: params}) do
    inverted_params = Enum.into(params, %{}, fn {key, value} -> {value, key} end)

    Enum.map_join(path_values, "/", fn path_part ->
      if Map.has_key?(inverted_params, path_part) do
        ":#{inverted_params[path_part]}"
      else
        path_part
      end
    end)
  end

  @spec add_query_params(String.t(), map(), [String.t()] | nil) :: String.t()
  defp add_query_params(uri, _, []), do: uri
  defp add_query_params(uri, _, nil), do: uri

  defp add_query_params(uri, params, take) do
    to_encode = Map.take(params, take)

    if to_encode == %{} do
      uri
    else
      uri <> "?" <> Plug.Conn.Query.encode(to_encode)
    end
  end
end
