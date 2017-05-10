defmodule Spandex.Task do
  require Spandex.Trace

  def async(name, fun) do
    trace_id = Spandex.Trace.current_trace_id()
    span_id = Spandex.Trace.current_span_id()

    if trace_id do
      Task.async(fn ->

        Spandex.Trace.continue_trace(trace_id, span_id, [])

        try do
          Spandex.Trace.span(name) do
            fun.()
          end
        after
          :ets.delete(:spandex_trace, self())
        end
      end)
    else
      Task.async(fun)
    end
  end

  def await(task, timeout \\ 5000) do
    Task.await(task, timeout)
  end
end
