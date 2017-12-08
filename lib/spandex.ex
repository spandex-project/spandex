defmodule Spandex do
  @moduledoc """
  Provides the entry point for the application, in addition to a standardized
  interface. The functions here call the corresponding functions on the
  configured adapter.
  """
  require Logger

  import Spandex.Adapters.Helpers

  defmacro span(name, do: body) do
    quote do
      if Spandex.disabled?() do
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

  def disabled?() do
    truthy?(Confex.get_env(:spandex, :disabled?)) or not(truthy?(Confex.get_env(:spandex, :adapter)))
  end

  defp truthy?(value) when value in [false, nil], do: false
  defp truthy?(_other), do: true

  delegate_to_adapter(:start_trace, [name])
  def start_trace(name, attributes) do
    case start_trace(name) do
      {:ok, trace_id} ->
        Logger.metadata([trace_id: trace_id])

        Spandex.update_span(attributes)
      {:error, error} -> {:error, error}
    end
  end

  delegate_to_adapter(:start_span, [name])
  def start_span(name, attributes) do
    case start_span(name) do
      {:ok, span_id} ->
        Logger.metadata([span_id: span_id])

        Spandex.update_span(attributes)
      {:error, error} -> {:error, error}
    end
  end

  delegate_to_adapter(:update_span, [context])
  delegate_to_adapter(:update_top_span, [context])
  delegate_to_adapter(:finish_trace, [])
  delegate_to_adapter(:finish_span, [])
  delegate_to_adapter(:span_error, [error])
  delegate_to_adapter(:continue_trace, [name, trace_id, span_id])
  delegate_to_adapter(:continue_trace_from_span, [name, span])
  delegate_to_adapter(:current_trace_id, [])
  delegate_to_adapter(:current_span_id, [])
  delegate_to_adapter(:current_span, [])
end
