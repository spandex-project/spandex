defmodule Spandex.Plug.EndTrace do
  @moduledoc """
  Finishes a trace, setting status and error based on the HTTP status.

  ## Options

  This plug accepts the following options:

  * `:tracer` - The tracing module to be used to start the trace. Required.
  * `:tracer_opts` - Any opts to be passed to the tracer when starting or continuing the trace.
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @default_opts [tracer_opts: []]

  @doc """
  Accepts opts for the plug, and underlying tracer.
  """
  @spec init(opts :: Keyword.t()) :: Keyword.t()
  def init(opts) do
    Keyword.merge(@default_opts, opts)
  end

  @spec call(conn :: Plug.Conn.t(), _opts :: Keyword.t()) :: Plug.Conn.t()
  def call(conn, opts) do
    tracer = opts[:tracer]
    tracer_opts = opts[:tracer_opts]

    opts =
      if conn.status in 200..399 do
        Keyword.merge([http: [status_code: conn.status]], tracer_opts)
      else
        Keyword.merge(
          [http: [status_code: conn.status], error: [error?: true]],
          tracer_opts
        )
      end

    if Utils.trace?(conn) do
      tracer.update_top_span(opts)

      tracer.finish_trace(tracer_opts)
    end

    conn
  end
end
