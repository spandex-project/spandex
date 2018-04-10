defmodule Spandex.Adapters.OpenTracing do
  @moduledoc """
  An open tracing implementation backed by otter.
  """

  @behaviour Spandex.Adapters.Adapter

  alias :otter, as: Otter

  require Logger

  @doc """
  Starts a trace context in process local storage.
  """
  @spec start_trace(String.t) :: {:ok, term} | {:error, term}
  def start_trace(name) do
    _ = finish_trace()

    case Spandex.Trace.get_trace() do
      nil ->
        top_span = Otter.start_with_tags(name, [service: Confex.get_env(:spandex, :service)])
        trace_id = trace_id(top_span)

        Logger.metadata([trace_id: trace_id])

        Spandex.Trace.start_trace(trace_id, [top_span])

        {:ok, trace_id}
      _ ->
        _ = Logger.error("Tried to start a trace over top of another trace.")

        {:error, :trace_context_already_present}
    end
  end

  @spec mandatory_top_span() :: String.t() | nil
  def mandatory_top_span(), do: nil

  @spec include_method_in_span_name?() :: boolean
  def include_method_in_span_name?() do
    false
  end

  @doc """
  Starts a span and adds it to the span stack.
  """
  @spec start_span(String.t, map) :: {:ok, term} | {:error, term}
  def start_span(name, attrs \\ %{})
  def start_span(name, %{log?: true}) do
    Spandex.Trace.update_span(&Otter.log(&1, name))
  end
  def start_span(name, attrs) do
    case Spandex.Trace.get_trace() do
      nil ->
        {:error, :no_trace_context}
      %{stack: [current_span | _], id: trace_id} ->
        all_tags = Enum.into(attrs, []) ++ [service: Confex.get_env(:spandex, :service)] ++ tags(current_span)
        new_span = Otter.start_with_tags(name, all_tags, trace_id, span_id(current_span))

        span_id = span_id(new_span)
        Logger.metadata(span_id: span_id)
        Spandex.Trace.start_span(new_span)

        {:ok, span_id}
      %{id: trace_id} ->
        new_span = Otter.start_with_tags(name, [service: Confex.get_env(:spandex, :service)], trace_id)
        span_id = span_id(new_span)

        Logger.metadata(span_id: span_id)
        Spandex.Trace.start_span(new_span)

        {:ok, span_id}
    end
  end

  @doc """
  Updates a span according to the provided context.
  See `Spandex.Datadog.Span.update/2` for more information.
  """
  @spec update_span(map) :: :ok | {:error, atom}
  def update_span(context) do
    Spandex.Trace.update_span(&do_update_span(&1, context))
  end

  @doc """
  Updates the top level span with information. Useful for setting overal trace context
  """
  @spec update_top_span(map) :: :ok | {:error, atom}
  def update_top_span(context) do
    Spandex.Trace.update_top_span(&do_update_span(&1, context))
  end

  @doc """
  Completes the current span, moving it from the top of the span stack
  to the list of completed spans.
  """
  @spec finish_span() :: :ok | {:error, atom}
  def finish_span() do
    Spandex.Trace.finish_span(&Otter.finish/1, save?: false)
  end

  @doc """
  Sends the trace to datadog and clears out the current trace data
  """
  @spec finish_trace() :: :ok | {:error, :no_trace_context}
  def finish_trace() do
    Spandex.Trace.finish_trace(&Otter.finish/1)
  end

  @doc """
  Gets the current trace id
  """
  @spec current_trace_id() :: term | nil | {:error, term}
  def current_trace_id() do
    Spandex.Trace.get_trace(%{id: nil}).id
  end

  @doc """
  Gets the current span id
  """
  @spec current_span_id() :: term | nil | {:error, term}
  def current_span_id() do
    case Spandex.Trace.get_span() do
      {:error, error} -> {:error, error}
      span -> span_id(span)
    end
  end

  @doc """
  Continues a trace given a name, a trace_id and a span_id
  """
  @spec continue_trace(String.t, term, term) :: {:ok, term} | {:error, term}
  def continue_trace(name, trace_id, span_id) do
    finish_trace()

    new_span = Otter.start_with_tags(name, [service: Confex.get_env(:spandex, :service)], trace_id, span_id)
    Spandex.Trace.start_trace(trace_id, [new_span])

    Logger.metadata(span_id: span_id, trace_id: trace_id)

    {:ok, span_id}
  end

  @spec span_error() :: :ok | {:error, term}
  def span_error() do
    update_span(%{error: true})
  end

  @doc """
  Attaches error data to the current span, and marks it as an error.
  """
  @spec span_error(Exception.t) :: :ok | {:error, term}
  def span_error(%{__struct__: type} = exception) do
    message = Exception.message(exception)
    stacktrace = Exception.format_stacktrace(System.stacktrace)

    update_span(%{error: true, error_message: message, stacktrace: stacktrace, error_type: type})
  end

  defp do_update_span(span, context) do
    Enum.reduce(context, span, fn {key, value}, span ->
      case key do
        :name ->
          rename(span, value)
        key ->
          Otter.tag(span, key, value)
      end
    end)
  end

  defp span_id(span), do: elem(span, 4)
  defp trace_id(span), do: elem(span, 2)
  defp tags(span), do: elem(span, 6)
  defp rename({title, timestamp, trace_id, _name, id, parent_id, tags, logs, duration}, name) do
    {title, timestamp, trace_id, name, id, parent_id, tags, logs, duration}
  end

end
