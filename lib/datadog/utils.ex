defmodule Spandex.Datadog.Utils do
  @moduledoc """
  A set of common utils specific (for now) to DataDog APM).
  """

  @max_id 9_223_372_036_854_775_807

  @doc """
  Returns the current timestamp in nanoseconds.
  """
  @spec now() :: non_neg_integer
  def now() do
    :os.system_time(:nanosecond)
  end

  @doc """
  Generates new span compatible id.
  """
  @spec next_id() :: non_neg_integer
  def next_id() do
    :rand.uniform(@max_id)
  end
end
