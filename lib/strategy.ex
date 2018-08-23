defmodule Spandex.Strategy do
  @moduledoc """
  The behaviour for a storage strategy for storing an ongoing trace.
  """
  @type tracer :: module

  alias Spandex.Trace

  @callback delete_trace(tracer) :: {:ok, Trace.t()} | {:error, term}
  @callback get_trace(tracer) :: {:ok, Trace.t()} | {:error, term}
  @callback put_trace(tracer, Trace.t()) :: {:ok, Trace.t()} | {:error, term}
  @callback trace_active?(tracer) :: boolean
end
