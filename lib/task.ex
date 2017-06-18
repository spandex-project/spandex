defmodule Spandex.Task do
  @moduledoc """
  Provides an alternative to `Task.async/1` that takes a name
  and makes sure that the child task's spans are appropriately
  tied to the current span of the caller.
  """
  require Spandex

  def async(name, fun) do
    with false <- Confex.get(:spandex, :disabled?, false),
         trace_id when not(is_tuple(trace_id)) <- Spandex.current_trace_id(),
         span_id when not(is_tuple(span_id)) <- Spandex.current_span_id()
    do
      Task.async(fn ->
        _ = Spandex.continue_trace("Task.async/0", trace_id, span_id)

        Spandex.span(name) do
          fun.()
        end
      end)
    else
      _error -> Task.async(fun)
    end
  end

  def await(task, timeout \\ 5000) do
    Task.await(task, timeout)
  end
end
