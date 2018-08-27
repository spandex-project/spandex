defmodule Spandex.Strategy.Pdict do
  @moduledoc """
  This stores traces in the local process dictionary, scoped by the
  tracer running the trace, such that you could have multiple traces
  going at one time by using a different tracer.
  """
  @behaviour Spandex.Strategy

  @impl Spandex.Strategy
  def trace_active?(trace_key) do
    Process.get({:spandex_trace, trace_key})
  end

  @impl Spandex.Strategy
  def get_trace(trace_key) do
    trace = Process.get({:spandex_trace, trace_key})

    if trace do
      {:ok, trace}
    else
      {:error, :no_trace_context}
    end
  end

  @impl Spandex.Strategy
  def put_trace(trace_key, trace) do
    Process.put({:spandex_trace, trace_key}, trace)

    {:ok, trace}
  end

  @impl Spandex.Strategy
  def delete_trace(trace_key) do
    {:ok, Process.delete({:spandex_trace, trace_key})}
  end
end
