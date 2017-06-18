defmodule Spandex.Adapters.Datadog do
  @moduledoc """
  A datadog APM implementation for spandex.
  """
  @behaviour Spandex.Adapters.Adapter

  @doc """
  Does any required setup on application start.
  """
  def startup() do
    services = Confex.get_map(:spandex, :datadog)[:services]
    application_name = Confex.get(:spandex, :application)

    for {service_name, type} <- services do
      Spandex.Datadog.Api.create_service(service_name, application_name, type)
    end

    :ok
  end

  @doc """
  Starts a trace context in process local storage.
  """
  require Logger
  def start_trace(name) do
    if Process.get(:spandex_trace) do
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

      _ = Process.put(:spandex_trace, %{id: trace_id, stack: [top_span], spans: [], start: now()})

      {:ok, trace_id}
    end
  end

  @doc """
  Starts a span and adds it to the span stack.
  """
  def start_span(name) do
    trace = Process.get(:spandex_trace, :undefined)
    case trace do
      :undefined ->
        start_trace(name)
      %{stack: [current_span|_]} ->
        new_span =
          current_span
          |> Spandex.Datadog.Span.child_of(name, datadog_id())
          |> Spandex.Datadog.Span.begin(now())

        _ = Process.put(:spandex_trace, %{trace | stack: [new_span | trace.stack]})

        {:ok, new_span.id}
      _ ->
        new_span =
          %Spandex.Datadog.Span{
            id: datadog_id(),
            trace_id: trace.id,
            name: name
          }
          |> Spandex.Datadog.Span.begin(now())

        _ = Process.put(:spandex_trace, %{trace | stack: [new_span | trace.stack]})

        {:ok, new_span.id}
    end
  end

  @doc """
  Updates a span according to the provided context.
  See `Spandex.Datadog.Span.update/3` for more information.
  """
  def update_span(context) do
    trace = Process.get(:spandex_trace, :undefined)

    if trace == :undefined do
      {:error, :no_trace_context}
    else
      new_stack = List.update_at(trace.stack, 0, fn span ->
        Spandex.Datadog.Span.update(span, context)
      end)

      _ = Process.put(:spandex_trace, %{trace | stack: new_stack})

      :ok
    end
  end

  @doc """
  Updates the top level span with information. Useful for setting overal trace context
  """
  def update_top_span(context) do
    trace = Process.get(:spandex_trace, :undefined)

    if trace == :undefined do
      {:error, :no_trace_context}
    else
      new_stack =
        trace.stack
        |> Enum.reverse()
        |> List.update_at(0, fn span ->
          Spandex.Datadog.Span.update(span, context)
        end)
        |> Enum.reverse()

      _ = Process.put(:spandex_trace, %{trace | stack: new_stack})

      :ok
    end
  end

  @doc """
  Updates all spans
  """
  def update_all_spans(context) do
    trace = Process.get(:spandex_trace, :undefined)

    if trace == :undefined do
      {:error, :no_trace_context}
    else
      new_stack = Enum.map(trace.stack, &Spandex.Datadog.Span.update(&1, context))
      new_spans = Enum.map(trace.spans, &Spandex.Datadog.Span.update(&1, context))

      _ = Process.put(:spandex_trace, %{trace | stack: new_stack, spans: new_spans})

      :ok
    end
  end

  @doc """
  Completes the current span, moving it from the top of the span stack
  to the list of completed spans.
  """
  def finish_span() do
    trace = Process.get(:spandex_trace, :undefined)

    cond do
      trace == :undefined ->
        {:error, :no_trace_context}
      Enum.empty?(trace.stack) ->
        {:error, :no_span_context}
      true ->
        new_stack = tl(trace.stack)
        completed_span =
          trace.stack
          |> hd()
          |> Spandex.Datadog.Span.update(%{completion_time: now()})

        _ = Process.put(:spandex_trace, %{trace | stack: new_stack, spans: [completed_span | trace.spans]})

        :ok
    end
  end

  @doc """
  Sends the trace to datadog and clears out the current trace data
  """
  def finish_trace() do
    _ = finish_span()
    trace = Process.get(:spandex_trace, :undefined)

    if trace == :undefined do
      {:error, :no_trace_context}
    else
      trace.spans
      |> Enum.map(&Spandex.Datadog.Span.update(&1, %{completion_time: now()}, false))
      |> Enum.map(&Spandex.Datadog.Span.to_json/1)
      |> Spandex.Datadog.Api.create_trace()

      Process.delete(:spandex_trace)

      :ok
    end
  end

  @doc """
  Gets the current trace id
  """
  def current_trace_id() do
    trace = Process.get(:spandex_trace, :undefined)

    if trace == :undefined do
      {:error, :no_trace_context}
    else
      trace.id
    end
  end

  @doc """
  Gets the current span id
  """
  def current_span_id() do
    trace = Process.get(:spandex_trace, :undefined)

    case trace do
      :undefined ->
        {:error, :no_trace_context}
      %{stack: [%{id: current_span_id}|_]} ->
        current_span_id
      _ ->
        nil
    end
  end

  @doc """
  Continues a trace given a name, a trace_id and a span_id
  """
  def continue_trace(name, trace_id, span_id) do
    trace = Process.get(:spandex_trace, :undefined)

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

        _ = Process.put(:spandex_trace, %{id: trace_id, stack: [top_span], spans: [], start: now()})
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
  def span_error(exception) do
    message = Exception.message(exception)
    stacktrace = Exception.format_stacktrace(System.stacktrace)
    type = exception.__struct__

    update_span(%{error: 1, error_message: message, stacktrace: stacktrace, error_type: type})
  end

  @doc """
  Returns the current timestamp in nanoseconds
  """
  def now() do
    DateTime.utc_now |> DateTime.to_unix(:nanoseconds)
  end

  @spec datadog_id() :: non_neg_integer
  defp datadog_id() do
    :rand.uniform(9223372036854775807)
  end
end