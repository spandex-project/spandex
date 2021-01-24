defmodule Spandex.Plug.StartTrace do
  @moduledoc """
  Starts a trace, skipping ignored routes or methods.
  Store info in Conn assigns if we actually trace the request.

  ## Options

  This plug accepts the following options:

  * `:tracer` - The tracing module to be used to start the trace. Required.
  * `:ignored_methods` - A list of strings representing methods to ignore. A good example would be `["OPTIONS"]`.
  * `:ignored_routes` - A list of strings or regexes. If it is a string, it must match exactly.
  * `:tracer_opts` - Any opts to be passed to the tracer when starting or continuing the trace.
  * `:span_name` - The name to be used for the top level span.
  """
  @behaviour Plug

  alias Spandex.Plug.Utils
  alias Spandex.SpanContext

  @default_opts [
    ignored_methods: [],
    ignored_routes: [],
    tracer_opts: [],
    span_name: "request"
  ]

  @doc """
  Accepts opts for the plug, and underlying tracer.
  """
  @spec init(opts :: Keyword.t()) :: Keyword.t()
  def init(opts), do: Keyword.merge(@default_opts, opts)

  @spec call(conn :: Plug.Conn.t(), opts :: Keyword.t()) :: Plug.Conn.t()
  def call(conn, opts) do
    if ignoring_request?(conn, opts) do
      Utils.trace(conn, false)
    else
      begin_tracing(conn, opts)
    end
  end

  @spec begin_tracing(conn :: Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  defp begin_tracing(conn, opts) do
    tracer = opts[:tracer]
    tracer_opts = opts[:tracer_opts]

    case tracer.distributed_context(conn, tracer_opts) do
      {:ok, %SpanContext{} = span_context} ->
        tracer.continue_trace("request", span_context, tracer_opts)
        Utils.trace(conn, true)

      {:error, :no_distributed_trace} ->
        tracer.start_trace(opts[:span_name], tracer_opts)
        Utils.trace(conn, true)

      _ ->
        conn
    end
  end

  @spec ignoring_request?(conn :: Plug.Conn.t(), Keyword.t()) :: boolean
  defp ignoring_request?(conn, opts) do
    ignored_method?(conn, opts) || ignored_route?(conn, opts)
  end

  @spec ignored_method?(conn :: Plug.Conn.t(), Keyword.t()) :: boolean
  defp ignored_method?(conn, opts) do
    conn.method in opts[:ignored_methods]
  end

  @spec ignored_route?(conn :: Plug.Conn.t(), Keyword.t()) :: boolean
  defp ignored_route?(conn, opts) do
    Enum.any?(opts[:ignored_routes], fn ignored_route ->
      match_route?(conn.request_path, ignored_route)
    end)
  end

  @spec match_route?(route :: String.t(), ignore :: %Regex{} | String.t()) :: boolean
  defp match_route?(ignore, ignore) when is_bitstring(ignore), do: true
  defp match_route?(_, ignore) when is_bitstring(ignore), do: false

  defp match_route?(route, ignore) do
    String.match?(route, ignore)
  end
end
