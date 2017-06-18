defmodule Spandex do
  use Application
  require Logger

  def start(_type, _args) do
    adapter = Confex.get(:spandex, :adapter)

    _ =
      if adapter do
        adapter.startup()
      else
        Logger.warn("No adapter configured for Spandex. Please configure one or disable spandex")
      end

    opts = [strategy: :one_for_one, name: Spandex.Supervisor]
    Supervisor.start_link([], opts)
  end

  defmacro span(name, do: body) do
    quote do
      if Confex.get(:spandex, :disabled?) do
        _ = unquote(name)
        unquote(body)
      else
        name = unquote(name)
        _ = Spandex.start_span(name)
        span_id = Spandex.current_span_id()
        Logger.metadata([span_id: span_id])

        try do
          return_value = unquote(body)
          _ = Spandex.finish_span()
          return_value
        rescue
          exception ->
            stacktrace = System.stacktrace()
            _ = Spandex.span_error(exception)
          reraise exception, stacktrace
        end
      end
    end
  end

  def update_span(context) do
    adapter = Confex.get(:spandex, :adapter)

    adapter.update_span(context)
  end

  def update_top_span(context) do
    adapter = Confex.get(:spandex, :adapter)

    adapter.update_top_span(context)
  end

  def finish_trace() do
    adapter = Confex.get(:spandex, :adapter)

    adapter.finish_trace()
  end

  def finish_span() do
    adapter = Confex.get(:spandex, :adapter)

    adapter.finish_span()
  end

  def span_error(error) do
    adapter = Confex.get(:spandex, :adapter)

    adapter.span_error(error)
  end

  def continue_trace(name, trace_id, span_id) do
    adapter = Confex.get(:spandex, :adapter)

    adapter.continue_trace(name, trace_id, span_id)
  end

  def current_trace_id() do
    adapter = Confex.get(:spandex, :adapter)

    adapter.current_trace_id()
  end

  def current_span_id() do
    adapter = Confex.get(:spandex, :adapter)

    adapter.current_span_id()
  end

  def start_trace(name) do
    adapter = Confex.get(:spandex, :adapter)

    adapter.start_trace(name)
  end

  def start_span(name) do
    adapter = Confex.get(:spandex, :adapter)

    adapter.start_span(name)
  end
end