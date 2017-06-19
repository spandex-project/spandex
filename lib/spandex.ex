defmodule Spandex do
  @moduledoc """
  Provides the entry point for the application, in addition to a standardized
  interface. The functions here call the corresponding functions on the
  configured adapter.
  """
  use Application
  require Logger

  import Spandex.Adapters.Helpers

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
        _ = Logger.metadata([span_id: span_id])

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

  delegate_to_adapter(:update_span, [context])
  delegate_to_adapter(:update_top_span, [context])
  delegate_to_adapter(:finish_trace, [])
  delegate_to_adapter(:finish_span, [])
  delegate_to_adapter(:span_error, [error])
  delegate_to_adapter(:continue_trace, [name, trace_id, span_id])
  delegate_to_adapter(:current_trace_id, [])
  delegate_to_adapter(:current_span_id, [])
  delegate_to_adapter(:start_trace, [name])
  delegate_to_adapter(:start_span, [name])
  delegate_to_adapter(:now, [])
end
