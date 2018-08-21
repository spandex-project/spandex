defmodule Benchmark.Adapter do
  @moduledoc """
  Try to do as little work as possible here, so that authors of real adapters
  can benchmark the performance of their libraries against this "null" one.
  """
  @behaviour Spandex.Adapter

  require Logger

  @impl Spandex.Adapter
  def trace_id, do: 1234

  @impl Spandex.Adapter
  def span_id, do: trace_id()

  @impl Spandex.Adapter
  def now, do: :os.system_time(:nano_seconds)

  @impl Spandex.Adapter
  def default_sender, do: Benchmark.Sender

  @impl Spandex.Adapter
  def distributed_context(_conn, _opts), do: {:error, :no_distributed_trace}
end
