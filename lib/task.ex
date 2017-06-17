defmodule Spandex.Task do
  def async(name, fun) do
    if Confex.get(:spandex, :disabled?) do
      Task.async(fun)
    else
      adapter = Confex.get(:spandex, :adapter)
      this_pid = self()

      Task.async(fn ->
        _ = adapter.continue_trace("task.async", this_pid)

        try do
          _ = adapter.start_span(name)
          return_value = fun.()
          _ = adapter.finish_span()

          return_value
        after
          _ = adapter.finish_trace()
        end
      end)
    end
  end

  def await(task, timeout \\ 5000) do
    Task.await(task, timeout)
  end
end
