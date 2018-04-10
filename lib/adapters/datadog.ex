defmodule Spandex.Adapters.Datadog do
  @moduledoc """
  A datadog APM implementation for spandex.
  """

  @behaviour Spandex.Adapters.Adapter

  alias Spandex.Datadog.Api
  alias Spandex.Datadog.Span
  alias Spandex.Datadog.Utils

  require Logger

  @doc """
  Starts a trace context in process local storage.
  """
  @spec start_trace(String.t) :: {:ok, term} | {:error, term}
  def start_trace(name) do
    _ = finish_trace()

    trace_id = Utils.next_id()
    top_span = Span.new(%{trace_id: trace_id, name: name})

    Logger.metadata([trace_id: trace_id])

    Spandex.Trace.start_trace(trace_id, [top_span])

    {:ok, trace_id}
  end

  @doc """
  Starts a span and adds it to the span stack.
  """
  @spec start_span(String.t, map) :: {:ok, term} | {:error, term}
  def start_span(name, attributes \\ %{}) do
    case Spandex.Trace.get_trace() do
      nil ->
        {:error, :no_trace_context}
      %{stack: [current_span | _]} ->
        new_span = Span.child_of(current_span, name)
        Logger.metadata(span_id: new_span.id)
        Spandex.Trace.start_span(new_span)
        Spandex.update_span(attributes)

        {:ok, new_span.id}
      %{id: trace_id} ->
        new_span = Span.new(%{trace_id: trace_id, name: name})

        Logger.metadata(span_id: new_span.id)
        Spandex.Trace.start_span(new_span)

        {:ok, new_span.id}
    end
  end

  @doc """
  Updates a span according to the provided context.
  See `Spandex.Datadog.Span.update/2` for more information.
  """
  @spec update_span(map) :: :ok | {:error, atom}
  def update_span(context) do
    Spandex.Trace.update_span(&Span.update(&1, context))
  end

  @doc """
  Updates the top level span with information. Useful for setting overal trace context
  """
  @spec update_top_span(map) :: :ok | {:error, atom}
  def update_top_span(context) do
    Spandex.Trace.update_top_span(&Span.update(&1, context))
  end

  @doc """
  Completes the current span, moving it from the top of the span stack
  to the list of completed spans.
  """
  @spec finish_span() :: :ok | {:error, atom}
  def finish_span() do
    Spandex.Trace.finish_span(&Span.stop/1)
  end

  @doc """
  Sends the trace to datadog and clears out the current trace data
  """
  @spec finish_trace() :: :ok | {:error, :no_trace_context}
  def finish_trace() do
    Spandex.Trace.finish_trace(&Span.stop/1, fn spans ->
      spans
      |> Enum.map(&Span.to_map/1)
      |> Api.create_trace()
    end)
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
      span -> span.id
    end
  end

  @doc """
  Continues a trace given a name, a trace_id and a span_id
  """
  @spec continue_trace(String.t, term, term) :: {:ok, term} | {:error, term}
  def continue_trace(name, trace_id, span_id) do
    case Spandex.Trace.get_trace() do
      nil ->
          Spandex.Trace.start_trace(trace_id)

          span = Span.new(%{trace_id: trace_id, parent_id: span_id, name: name})

          Spandex.Trace.start_span(span)
        {:ok, trace_id}
      %{id: ^trace_id} ->
        span = Span.new(%{trace_id: trace_id, parent_id: span_id, name: name})
        Spandex.Trace.start_span(span)
      _ ->
        {:error, :trace_already_present}
    end
  end

  @spec span_error() :: :ok | {:error, term}
  def span_error() do
    update_span(%{error: 1})
  end

  @doc """
  Attaches error data to the current span, and marks it as an error.
  """
  @spec span_error(Exception.t) :: :ok | {:error, term}
  def span_error(%{__struct__: type} = exception) do
    message = Exception.message(exception)
    stacktrace = Exception.format_stacktrace(System.stacktrace)

    update_span(%{error: 1, error_message: message, stacktrace: stacktrace, error_type: type})
  end
end
