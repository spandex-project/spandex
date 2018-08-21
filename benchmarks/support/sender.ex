defmodule Benchmark.Sender do
  @moduledoc """
  Don't count the time it takes to send traces to a tracing back-end in our benchmarks. That would be accounted-for in
  the Adapter library's benchmarks, if available.
  """
  def send_spans(spans), do: :ok
end
