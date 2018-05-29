defmodule Spandex do
  @moduledoc """
  The functions here call the corresponding functions on the configured adapter.
  """
  require Logger

  def start_trace(name, attributes, opts) do
    adapter = opts[:adapter]

    case adapter.start_trace(name, opts) do
      {:ok, trace_id} ->
        Logger.metadata(trace_id: trace_id)

        adapter.update_span(attributes, opts)
        {:ok, trace_id}

      {:error, error} ->
        {:error, error}
    end
  end

  def start_span(name, attributes, opts) do
    adapter = opts[:adapter]

    case adapter.start_span(name, opts) do
      {:ok, span_id} ->
        Logger.metadata(span_id: span_id)

        adapter.update_span(attributes, opts)
        {:ok, span_id}

      {:error, error} ->
        {:error, error}
    end
  end

  def update_span(attributes, opts) do
    adapter = opts[:adapter]

    adapter.update_span(attributes, opts)
  end

  def update_top_span(attributes, opts) do
    adapter = opts[:adapter]

    adapter.update_top_span(attributes, opts)
  end

  # All of these need to honor `disabled?: true`
  def finish_trace(opts) do
    wrap_adapter(opts, fn adapter ->
      adapter.finish_trace(opts)
    end)
  end

  def finish_span(opts) do
    wrap_adapter(opts, fn adapter ->
      adapter.finish_span(opts)
    end)
  end

  def span_error(error, opts) do
    wrap_adapter(opts, fn adapter ->
      adapter.span_error(error, opts)
    end)
  end

  def continue_trace(name, trace_id, span_id, opts) do
    wrap_adapter(opts, fn adapter ->
      adapter.continue_trace(name, trace_id, span_id, opts)
    end)
  end

  def continue_trace_from_span(name, span, opts) do
    wrap_adapter(opts, fn adapter ->
      adapter.continue_trace_from_span(name, span, opts)
    end)
  end

  def current_trace_id(opts) do
    wrap_adapter(opts, {:error, :no_trace}, fn adapter ->
      adapter.current_trace_id(opts)
    end)
  end

  def current_span_id(opts) do
    wrap_adapter(opts, {:error, :no_trace}, fn adapter ->
      adapter.current_span_id(opts)
    end)
  end

  def current_span(opts) do
    wrap_adapter(opts, {:error, :no_trace}, fn adapter ->
      adapter.current_span(opts)
    end)
  end

  def distributed_context(conn, opts) do
    wrap_adapter(opts, {:error, :disabled}, fn adapter ->
      adapter.distributed_context(conn, opts)
    end)
  end

  defp wrap_adapter(opts, ret \\ {:ok, :disabled}, fun) do
    if opts[:disabled?] == true do
      ret
    else
      adapter = opts[:adapter]
      fun.(adapter)
    end
  end
end
