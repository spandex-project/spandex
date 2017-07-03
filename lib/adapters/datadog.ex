defmodule Spandex.Adapters.Datadog do
  @moduledoc """
  A datadog APM implementation for spandex.
  """

  @behaviour Spandex.Adapters.Adapter

  require Logger

  @doc """
  Does any required setup on application start.
  """
  @spec startup() :: :ok | {:error, term}
  def startup() do
    services = Confex.get_env(:spandex, :datadog)[:services]
    application_name = Confex.get_env(:spandex, :application)

    for {service_name, type} <- services do
      Spandex.Datadog.Api.create_service(service_name, application_name, type)
    end

    :ok
  end

  @doc """
  Starts a trace context in process local storage.
  """
  @spec start_trace(String.t) :: {:ok, term} | {:error, term}
  def start_trace(name) do
    if get_trace() do
      Logger.error("Tried to start a trace over top of another trace.")
    else
      trace_id = datadog_id()
      top_span =
        %Spandex.Datadog.Span{
          id: datadog_id(),
          trace_id: trace_id,
          name: name
        }
        |> Spandex.Datadog.Span.begin(now())

      put_trace(%{id: trace_id, stack: [top_span], spans: [], start: now()})

      {:ok, trace_id}
    end
  end

  @doc """
  Starts a span and adds it to the span stack.
  """
  @spec start_span(String.t) :: {:ok, term} | {:error, term}
  def start_span(name) do
    trace = get_trace(:undefined)
    case trace do
      :undefined ->
        {:error, :no_trace_context}
      %{stack: [current_span | _]} ->
        new_span =
          current_span
          |> Spandex.Datadog.Span.child_of(name, datadog_id())
          |> Spandex.Datadog.Span.begin(now())

        put_trace(%{trace | stack: [new_span | trace.stack]})

        {:ok, new_span.id}
      _ ->
        new_span =
          %Spandex.Datadog.Span{
            id: datadog_id(),
            trace_id: trace.id,
            name: name
          }
          |> Spandex.Datadog.Span.begin(now())

        put_trace(%{trace | stack: [new_span | trace.stack]})

        {:ok, new_span.id}
    end
  end

  @doc """
  Updates a span according to the provided context.
  See `Spandex.Datadog.Span.update/3` for more information.
  """
  @spec update_span(map) :: :ok | {:error, term}
  def update_span(context) do
    trace = get_trace()

    if trace do
      new_stack = List.update_at(trace.stack, 0, fn span ->
        Spandex.Datadog.Span.update(span, context)
      end)

      put_trace(%{trace | stack: new_stack})

      :ok
    else
      {:error, :no_trace_context}
    end
  end

  @doc """
  Updates the top level span with information. Useful for setting overal trace context
  """
  @spec update_top_span(map) :: :ok | {:error, term}
  def update_top_span(context) do
    trace = get_trace()

    if trace do
      new_stack =
        trace.stack
        |> Enum.reverse()
        |> List.update_at(0, fn span ->
          Spandex.Datadog.Span.update(span, context)
        end)
        |> Enum.reverse()

      put_trace(%{trace | stack: new_stack})

      :ok
    else
      {:error, :no_trace_context}
    end
  end

  @doc """
  Updates all spans
  """
  @spec update_all_spans(map) :: :ok | {}
  def update_all_spans(context) do
    trace = get_trace()
    if trace do
      new_stack = Enum.map(trace.stack, &Spandex.Datadog.Span.update(&1, context))
      new_spans = Enum.map(trace.spans, &Spandex.Datadog.Span.update(&1, context))

      put_trace(%{trace | stack: new_stack, spans: new_spans})

      :ok
    else
      {:error, :no_trace_context}
    end
  end

  @doc """
  Completes the current span, moving it from the top of the span stack
  to the list of completed spans.
  """
  @spec finish_span() :: :ok | {:error, term}
  def finish_span() do
    trace = get_trace()

    cond do
      is_nil(trace) ->
        {:error, :no_trace_context}
      Enum.empty?(trace.stack) ->
        {:error, :no_span_context}
      true ->
        new_stack = tl(trace.stack)
        completed_span =
          trace.stack
          |> hd()
          |> Spandex.Datadog.Span.update(%{completion_time: now()}, false)

        put_trace(%{trace | stack: new_stack, spans: [completed_span | trace.spans]})

        :ok
    end
  end

  @doc """
  Sends the trace to datadog and clears out the current trace data
  """
  @spec finish_trace() :: :ok | {:error, :no_trace_context}
  def finish_trace() do
    trace = get_trace()

    if trace do
      unfinished_spans = Enum.map(trace.stack, &Spandex.Datadog.Span.update(&1, %{completion_time: now()}, false))

      trace.spans
      |> Kernel.++(unfinished_spans)
      |> Enum.map(&Spandex.Datadog.Span.update(&1, %{completion_time: now()}, false))
      |> Enum.map(&Spandex.Datadog.Span.to_map/1)
      |> Spandex.Datadog.Api.create_trace()

      delete_trace()

      :ok
    else
      {:error, :no_trace_context}
    end
  end

  @doc """
  Gets the current trace id
  """
  @spec current_trace_id() :: term | nil | {:error, term}
  def current_trace_id() do
    %{id: id} = get_trace(%{id: nil})
    id
  end

  @doc """
  Gets the current span id
  """
  @spec current_span_id() :: term | nil | {:error, term}
  def current_span_id() do
    case get_trace() do
      %{stack: [%{id: current_span_id} | _]} ->
        current_span_id
      _ ->
        nil
    end
  end

  @doc """
  Continues a trace given a name, a trace_id and a span_id
  """
  @spec continue_trace(String.t, term, term) :: {:ok, term} | {:error, term}
  def continue_trace(name, trace_id, span_id) do
    trace = get_trace(:undefined)

    cond do
      trace == :undefined ->
        top_span =
          %Spandex.Datadog.Span{
            id: datadog_id(),
            trace_id: trace_id,
            parent_id: span_id,
            name: name
          }
          |> Spandex.Datadog.Span.begin(now())

        put_trace(%{id: trace_id, stack: [top_span], spans: [], start: now()})
        {:ok, trace_id}
      trace_id == trace.id ->
        start_span(name)
      true ->
        {:error, :trace_already_present}
    end
  end

  @doc """
  Attaches error data to the current span, and marks it as an error.
  """
  @spec span_error(Exception.t) :: :ok | {:error, term}
  def span_error(exception = %{__struct__: type}) do
    message = Exception.message(exception)
    stacktrace = Exception.format_stacktrace(System.stacktrace)

    update_span(%{error: 1, error_message: message, stacktrace: stacktrace, error_type: type})
  end

  @doc """
  Returns the current timestamp in nanoseconds
  """
  @spec now() :: non_neg_integer
  def now() do
    DateTime.utc_now |> DateTime.to_unix(:nanoseconds)
  end

  @spec datadog_id() :: non_neg_integer
  defp datadog_id() do
    :rand.uniform(9_223_372_036_854_775_807)
  end

  @spec get_trace(term) :: term
  defp get_trace(default \\ nil) do
    Process.get(:spandex_trace, default)
  end

  @spec put_trace(term) :: term | nil
  defp put_trace(updates) do
    Process.put(:spandex_trace, updates)
  end

  @spec delete_trace() :: term | nil
  defp delete_trace() do
    Process.delete(:spandex_trace)
  end
end
