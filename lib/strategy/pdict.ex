defmodule Spandex.Strategy.Pdict do
  @moduledoc """
  This stores traces in the local process dictionary, scoped by the
  tracer running the trace, such that you could have multiple traces
  going at one time by using a different tracer.
  """
  @behaviour Spandex.Strategy

  @impl Spandex.Strategy
  def get_trace(tracer) do
    Process.get({:spandex_trace, tracer})
  end

  @impl Spandex.Strategy
  def put_trace(tracer, trace) do
    Process.put({:spandex_trace, tracer}, trace)

    {:ok, trace}
  end

  @impl Spandex.Strategy
  def delete_trace(tracer) do
    Process.delete({:spandex_trace, tracer})

    :ok
  end
end
