defmodule Spandex.Plug.EndTrace do
  @moduledoc """
  Finishes a trace, setting status and error based on the HTTP status.
  """
  @behaviour Plug

  alias Spandex.Plug.Utils

  @init_opts Optimal.schema(
               opts: [
                 tracer: :atom,
                 tracer_opts: :keyword
               ],
               defaults: [
                 tracer_opts: []
               ],
               required: [:tracer],
               describe: [
                 tracer: "The tracing module to be used to start the trace.",
                 tracer_opts:
                   "Any opts to be passed to the tracer when starting or continuing the trace."
               ]
             )

  @spec init(opts :: Keyword.t()) :: Keyword.t()
  def init(opts) do
    Optimal.validate!(opts, @init_opts)
  end

  @spec call(conn :: Plug.Conn.t(), _opts :: Keyword.t()) :: Plug.Conn.t()
  def call(conn, opts) do
    tracer = opts[:tracer]
    tracer_opts = opts[:tracer_opts]

    if Utils.trace?(conn) do
      tracer.update_top_span(
        %{
          status: conn.status,
          error: error_count(conn)
        },
        tracer_opts
      )

      tracer.finish_trace(tracer_opts)
    end

    conn
  end

  defp error_count(%{status: status}) when status in 200..399,
    do: 0

  defp error_count(%{status: _status}),
    do: 1
end
