defmodule Spandex.Task do
  @moduledoc """
  Provides an alternative to `Task.async/1` that takes a name
  and makes sure that the child task's spans are appropriately
  tied to the current span of the caller.

  When awaiting these tasks, always use `Spandex.Task.await/2`,
  as it adds a span for awaiting, and handles the output of the
  spandex task appropriately.
  """
  require Spandex

  def async(name, level \\ Spandex.default_level(), fun) do
    with false <- Spandex.disabled?(),
         span when not is_tuple(span) <- Spandex.current_span(),
         true <- Spandex.should_span?(level) do
      Task.async(fn ->
        _ = Spandex.continue_trace_from_span("Spandex.Task.async/2", span)

        result =
          Spandex.span name do
            fun.()
          end

        _ = Spandex.finish_trace()

        {:spandex_span, name, result}
      end)
    else
      _error -> Task.async(fun)
    end
  end

  def await(task, timeout \\ 5000, level \\ Spandex.default_level()) do
    if Spandex.should_span?(level) do
      Spandex.span "Spandex.Task.await/2" do
        case Task.await(task, timeout) do
          {:spandex_span, name, result} ->
            Spandex.update_span(%{name: "Spandex.Task.await/2:#{name}"})

            result

          other ->
            other
        end
      end
    else
      case Task.await(task, timeout) do
        {:spandex_span, _name, result} ->
          result

        other ->
          other
      end
    end
  end
end
