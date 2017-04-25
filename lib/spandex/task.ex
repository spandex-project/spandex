defmodule Spandex.Task do
  require Spandex.Trace

  def async(name, fun) do
    trace_pid =
      :spandex_trace
      |> :ets.lookup(self())
      |> Enum.at(0)
      |> Kernel.||({nil, nil})
      |> elem(1)

    if trace_pid do
      Task.async(fn ->
        :ets.insert(:spandex_trace, {self(), trace_pid})

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
