defmodule Spandex.Strategy do
  @moduledoc """
  The behaviour for a storage strategy for storing an ongoing trace.
  """
  @type tracer :: module

  alias Spandex.Trace

  @callback get_trace(tracer) :: Trace.t() | nil
  @callback put_trace(tracer, Trace.t()) :: {:ok, Trace.t()} | {:error, term}
  @callback delete_trace(tracer) :: :ok | {:error, term}
end
