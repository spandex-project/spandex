defmodule Spandex.Adapter do
  @moduledoc """
  The callbacks required to implement the Spandex.Adapter behaviour.
  """

  @doc """
  Creates a `Spandex.SpanContext` from a `Plug.Conn` or request headers.
  """
  @callback distributed_context(
              conn_or_headers :: Plug.Conn.t() | Spandex.headers(),
              opts :: Spandex.Tracer.opts()
            ) ::
              {:ok, Spandex.SpanContext.t()} | {:error, atom()}

  @doc """
  Injects distributed context information into request headers for further propagation.
  """
  @callback inject_context(
              headers :: Spandex.headers(),
              span_context :: Spandex.SpanContext.t(),
              opts :: Spandex.Tracer.opts()
            ) ::
              Spandex.headers()

  @doc """
  Generates a trace ID for a new trace.
  """
  @callback trace_id() :: Spandex.id()

  @doc """
  Generates a span ID for a new span.
  """
  @callback span_id() :: Spandex.id()

  @doc """
  Returns the current time with the precision expected by the adapter.
  """
  @callback now() :: Spandex.timestamp()

  @doc """
  Returns the module responsible for sending traces to the tracing backend.
  """
  @callback default_sender() :: module()

  @doc """
  Returns the default priority to be used for new traces.
  """
  @callback default_priority() :: integer()
end
