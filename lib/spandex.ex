defmodule Spandex do
  @moduledoc """
  The functions here call the corresponding functions on the configured adapter.
  """
  require Logger

  alias Spandex.{
    Span,
    SpanContext,
    Trace,
    Tracer
  }

  @type headers :: [{atom, binary}] | [{binary, binary}] | %{binary => binary}

  @typedoc "Used for Span and Trace IDs (type defined by adapters)"
  @type id :: term()

  @typedoc "Unix timestamp in nanoseconds"
  @type timestamp :: non_neg_integer()

  @doc """
  Starts a new trace.

  Span updates for the first span may be passed in. They are skipped if they are
  invalid updates. As such, if you aren't sure if your updates are valid, it is
  safer to perform a second call to `update_span/2` and check the return value.
  """
  @spec start_trace(binary(), Tracer.opts()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :trace_running}
          | {:error, [Optimal.error()]}
  def start_trace(_, :disabled), do: {:error, :disabled}

  def start_trace(name, opts) do
    strategy = opts[:strategy]

    if strategy.trace_active?(opts[:trace_key]) do
      Logger.error("Tried to start a trace over top of another trace.")
      {:error, :trace_running}
    else
      do_start_trace(name, opts)
    end
  end

  @doc """
  Start a new span.

  Span updates for that span may be passed in. They are skipped if they are
  invalid updates. As such, if you aren't sure if your updates are valid, it is
  safer to perform a second call to `update_span/2` and check the return value.
  """
  @spec start_span(String.t(), Tracer.opts()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
  def start_span(_, :disabled), do: {:error, :disabled}

  def start_span(name, opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:trace_key]) do
      {:error, :no_trace_context} = error ->
        error

      {:error, _} = error ->
        error

      {:ok, trace} ->
        do_start_span(name, trace, opts)
    end
  end

  @doc """
  Updates the current span.

  In the case of an invalid update, validation errors are returned.
  """
  @spec update_span(Tracer.opts(), boolean()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, :no_span_context}
          | {:error, [Optimal.error()]}
  def update_span(opts, top? \\ false)
  def update_span(:disabled, _), do: {:error, :disabled}

  def update_span(opts, top?) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:trace_key]) do
      {:error, :no_trace_context} = error ->
        error

      {:ok, %Trace{stack: []}} ->
        {:error, :no_span_context}

      {:ok, trace} ->
        do_update_span(trace, opts, top?)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Updates the top-most parent span.

  Any spans that have already been started will not inherit any of the updates
  from that span. For instance, if you change `service`, it will not be
  reflected in already-started spans.

  In the case of an invalid update, validation errors are returned.
  """
  @spec update_top_span(Tracer.opts()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, [Optimal.error()]}
  def update_top_span(:disabled), do: {:error, :disabled}

  def update_top_span(opts), do: update_span(opts, true)

  @doc """
  Updates all spans, whether complete or in-progress.

  In the case of an invalid update for any span, validation errors are returned.
  """
  @spec update_all_spans(Tracer.opts()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, [Optimal.error()]}
  def update_all_spans(:disabled), do: {:error, :disabled}

  def update_all_spans(opts) do
    strategy = opts[:strategy]

    with {:ok, %Trace{stack: stack, spans: spans} = trace} <- strategy.get_trace(opts[:trace_key]),
         {:ok, new_spans} <- update_many_spans(spans, opts),
         {:ok, new_stack} <- update_many_spans(stack, opts) do
      strategy.put_trace(opts[:trace_key], %{trace | stack: new_stack, spans: new_spans})
    end
  end

  @doc """
  Finishes the current trace.

  Span updates for the top span may be passed in. They are skipped if they are
  invalid updates. As such, if you aren't sure if your updates are valid, it is
  safer to perform a call to `update_span/2` and check the return value before
  finishing the trace.
  """
  @spec finish_trace(Tracer.opts()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
  def finish_trace(:disabled), do: {:error, :disabled}

  def finish_trace(opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:trace_key]) do
      {:error, :no_trace_context} = error ->
        Logger.error("Tried to finish a trace without an active trace.")
        error

      {:ok, %Trace{spans: spans, stack: stack} = trace} ->
        unfinished_spans =
          stack
          |> List.update_at(0, &update_or_keep(&1, opts))
          |> Enum.map(&ensure_completion_time_set(&1, adapter))

        sender = opts[:sender] || adapter.default_sender()
        # TODO: We need to define a behaviour for the Sender API.
        sender.send_trace(%Trace{trace | spans: spans ++ unfinished_spans, stack: []})
        strategy.delete_trace(opts[:trace_key])

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Finishes the current span.

  Span updates for that span may be passed in. They are skipped if they are
  invalid updates. As such, if you aren't sure if your updates are valid, it is
  safer to perform a call to `update_span/2` and check the return value before
  finishing the span.
  """
  @spec finish_span(Tracer.opts()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, :no_span_context}
  def finish_span(:disabled), do: {:error, :disabled}

  def finish_span(opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:trace_key]) do
      {:error, :no_trace_context} = error ->
        error

      {:ok, %Trace{stack: []}} ->
        Logger.error("Tried to finish a span without an active span.")
        {:error, :no_span_context}

      {:ok, %Trace{stack: [span | tail], spans: spans} = trace} ->
        finished_span =
          span
          |> update_or_keep(opts)
          |> ensure_completion_time_set(adapter)

        strategy.put_trace(opts[:trace_key], %{
          trace
          | stack: tail,
            spans: [finished_span | spans]
        })

        {:ok, finished_span}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Updates the current span with error details.

  In the case of an invalid value, validation errors are returned.
  """
  @spec span_error(Exception.t(), Enum.t(), Tracer.opts()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, :no_span_context}
          | {:error, [Optimal.error()]}
  def span_error(_error, _stacktrace, :disabled), do: {:error, :disabled}

  def span_error(exception, stacktrace, opts) do
    updates = [exception: exception, stacktrace: stacktrace]
    update_span(Keyword.put_new(opts, :error, updates))
  end

  @doc """
  Returns the id of the currently-running trace.
  """
  @spec current_trace_id(Tracer.opts()) :: Spandex.id() | nil
  def current_trace_id(:disabled), do: nil

  def current_trace_id(opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:trace_key]) do
      {:ok, %Trace{id: id}} ->
        id

      {:error, _} ->
        # TODO: Alter the return type of this interface to allow for returning
        # errors from fetching the trace.
        nil
    end
  end

  @doc """
  Returns the id of the currently-running span.
  """
  @spec current_span_id(Tracer.opts()) :: Spandex.id() | nil
  def current_span_id(:disabled), do: nil

  def current_span_id(opts) do
    case current_span(opts) do
      nil -> nil
      span -> span.id
    end
  end

  @doc """
  Returns the `%Span{}` struct for the currently-running span
  """
  @spec current_span(Tracer.opts()) :: Span.t() | nil
  def current_span(:disabled), do: nil

  def current_span(opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:trace_key]) do
      {:ok, %Trace{stack: []}} ->
        nil

      {:ok, %Trace{stack: [span | _]}} ->
        span

      {:error, _} ->
        # TODO: Alter the return type of this interface to allow for returning
        # errors from fetching the trace.
        nil
    end
  end

  @doc """
  Returns the current `%SpanContext{}` or an error.

  ### DEPRECATION WARNING

  Expect changes to this in the future, as this will eventualy be refactored to
  only ever return a `%SpanContext{}`, or at least to always return something
  consistent.
  """
  @spec current_context(Tracer.opts()) ::
          {:ok, SpanContext.t()}
          | {:error, :disabled}
          | {:error, :no_span_context}
          | {:error, :no_trace_context}
  def current_context(:disabled), do: {:error, :disabled}

  def current_context(opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:trace_key]) do
      {:ok, %Trace{id: trace_id, priority: priority, baggage: baggage, stack: [%Span{id: span_id} | _]}} ->
        {:ok, %SpanContext{trace_id: trace_id, priority: priority, baggage: baggage, parent_id: span_id}}

      {:ok, %Trace{stack: []}} ->
        {:error, :no_span_context}

      {:error, _} ->
        {:error, :no_trace_context}
    end
  end

  @doc """
  Given a `%SpanContext{}`, resumes a trace from a different process or service.

  Span updates for the top span may be passed in. They are skipped if they are
  invalid updates. As such, if you aren't sure if your updates are valid, it is
  safer to perform a second call to `update_span/2` and check the return value.
  """
  @spec continue_trace(String.t(), SpanContext.t(), Keyword.t()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :trace_already_present}
  def continue_trace(_, _, :disabled), do: {:error, :disabled}

  def continue_trace(name, %SpanContext{} = span_context, opts) do
    strategy = opts[:strategy]

    if strategy.trace_active?(opts[:trace_key]) do
      Logger.error("Tried to continue a trace over top of another trace.")
      {:error, :trace_already_present}
    else
      do_continue_trace(name, span_context, opts)
    end
  end

  @doc """
  Given a trace_id and span_id, resumes a trace from a different process or service.

  Span updates for the top span may be passed in. They are skipped if they are
  invalid updates. As such, if you aren't sure if your updates are valid, it is
  safer to perform a second call to `update_span/2` and check the return value.
  """
  @spec continue_trace(String.t(), Spandex.id(), Spandex.id(), Keyword.t()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :trace_already_present}
  @deprecated "Use continue_trace/3 instead"
  def continue_trace(_, _, _, :disabled), do: {:error, :disabled}

  def continue_trace(name, trace_id, span_id, opts) do
    continue_trace(name, %SpanContext{trace_id: trace_id, parent_id: span_id}, opts)
  end

  @doc """
  Given a span struct, resumes a trace from a different process or service.

  Span updates for the top span may be passed in. They are skipped if they are
  invalid updates. As such, if you aren't sure if your updates are valid, it is
  safer to perform a second call to `update_span/2` and check the return value.
  """
  @spec continue_trace_from_span(String.t(), Span.t(), Tracer.opts()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :trace_already_present}
  def continue_trace_from_span(_name, _span, :disabled), do: {:error, :disabled}

  def continue_trace_from_span(name, span, opts) do
    strategy = opts[:strategy]

    if strategy.trace_active?(opts[:trace_key]) do
      Logger.error("Tried to continue a trace over top of another trace.")
      {:error, :trace_already_present}
    else
      do_continue_trace_from_span(name, span, opts)
    end
  end

  @doc """
  Returns the context from a given set of HTTP headers, as determined by the adapter.
  """
  @spec distributed_context(Plug.Conn.t(), Tracer.opts()) ::
          {:ok, SpanContext.t()}
          | {:error, :disabled}
  def distributed_context(_, :disabled), do: {:error, :disabled}

  def distributed_context(conn, opts) do
    adapter = opts[:adapter]
    adapter.distributed_context(conn, opts)
  end

  @doc """
  Alters headers to include the outgoing HTTP headers necessary to continue a
  distributed trace, as determined by the adapter.
  """
  @spec inject_context(headers(), SpanContext.t(), Tracer.opts()) :: headers()
  def inject_context(headers, %SpanContext{} = span_context, opts) do
    adapter = opts[:adapter]
    adapter.inject_context(headers, span_context, opts)
  end

  # Private Helpers

  defp update_many_spans(spans, opts) do
    spans
    |> Enum.reduce({:ok, []}, fn
      span, {:ok, acc} ->
        case Span.update(span, opts) do
          {:ok, updated} ->
            {:ok, [updated | acc]}

          {:error, error} ->
            {:error, error}
        end

      _, {:error, error} ->
        {:error, error}
    end)
    |> case do
      {:ok, list} ->
        {:ok, Enum.reverse(list)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_continue_trace(name, span_context, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    with {:ok, top_span} <- span(name, opts, span_context, adapter) do
      Logger.metadata(trace_id: span_context.trace_id, span_id: top_span.id)

      trace = %Trace{
        id: span_context.trace_id,
        priority: span_context.priority,
        baggage: span_context.baggage,
        stack: [top_span],
        spans: []
      }

      strategy.put_trace(opts[:trace_key], trace)
    end
  end

  defp do_continue_trace_from_span(name, span, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    with {:ok, span} <- Span.child_of(span, name, adapter.span_id(), adapter.now(), opts) do
      trace = %Trace{id: adapter.trace_id(), stack: [span], spans: []}
      strategy.put_trace(opts[:trace_key], trace)
    end
  end

  defp do_start_span(name, %Trace{stack: [current_span | _]} = trace, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    with {:ok, span} <- Span.child_of(current_span, name, adapter.span_id(), adapter.now(), opts),
         {:ok, _trace} <- strategy.put_trace(opts[:trace_key], %{trace | stack: [span | trace.stack]}) do
      Logger.metadata(span_id: span.id, trace_id: trace.id)
      {:ok, span}
    end
  end

  defp do_start_span(name, %Trace{stack: [], id: trace_id} = trace, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]
    span_context = %SpanContext{trace_id: trace_id}

    with {:ok, span} <- span(name, opts, span_context, adapter),
         {:ok, _trace} <- strategy.put_trace(opts[:trace_key], %{trace | stack: [span]}) do
      Logger.metadata(span_id: span.id, trace_id: trace_id)
      {:ok, span}
    end
  end

  defp do_start_trace(name, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]
    trace_id = adapter.trace_id()
    span_context = %SpanContext{trace_id: trace_id}

    with {:ok, span} <- span(name, opts, span_context, adapter) do
      Logger.metadata(trace_id: trace_id, span_id: span.id)
      trace = %Trace{spans: [], stack: [span], id: trace_id}
      strategy.put_trace(opts[:trace_key], trace)
    end
  end

  defp do_update_span(%Trace{stack: stack} = trace, opts, true) do
    strategy = opts[:strategy]

    top_span = Enum.at(stack, -1)

    with {:ok, updated} <- Span.update(top_span, opts),
         new_stack <- List.replace_at(stack, -1, updated),
         {:ok, _trace} <- strategy.put_trace(opts[:trace_key], %{trace | stack: new_stack}) do
      {:ok, updated}
    end
  end

  defp do_update_span(%Trace{stack: [current_span | other_spans]} = trace, opts, false) do
    strategy = opts[:strategy]

    with {:ok, updated} <- Span.update(current_span, opts),
         new_stack <- [updated | other_spans],
         {:ok, _trace} <- strategy.put_trace(opts[:trace_key], %{trace | stack: new_stack}) do
      {:ok, updated}
    end
  end

  defp ensure_completion_time_set(%Span{completion_time: nil} = span, adapter) do
    update_or_keep(span, completion_time: adapter.now())
  end

  defp ensure_completion_time_set(%Span{} = span, _adapter), do: span

  defp span(name, opts, span_context, adapter) do
    opts
    |> Keyword.put_new(:name, name)
    |> Keyword.put(:trace_id, span_context.trace_id)
    |> Keyword.put(:parent_id, span_context.parent_id)
    |> Keyword.put(:start, adapter.now())
    |> Keyword.put(:id, adapter.span_id())
    |> Span.new()
  end

  defp update_or_keep(span, opts) do
    case Span.update(span, opts) do
      {:error, _} -> span
      {:ok, span} -> span
    end
  end
end
