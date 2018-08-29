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

  @typedoc "Used for Span and Trace IDs (type defined by adapters)"
  @type id :: term()

  @typedoc "Unix timestamp in nanoseconds"
  @type timestamp :: non_neg_integer()

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

  @spec start_span(String.t(), Tracer.opts()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, [Optimal.error()]}
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

  @spec update_top_span(Tracer.opts()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, [Optimal.error()]}
  def update_top_span(:disabled), do: {:error, :disabled}

  def update_top_span(opts), do: update_span(opts, true)

  @spec update_all_spans(Tracer.opts()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, [Optimal.error()]}
  def update_all_spans(:disabled), do: {:error, :disabled}

  def update_all_spans(opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:trace_key]) do
      {:error, :no_trace_context} = error ->
        error

      {:ok, %Trace{stack: stack, spans: spans} = trace} ->
        new_stack = Enum.map(stack, &update_or_keep(&1, opts))
        new_spans = Enum.map(spans, &update_or_keep(&1, opts))
        strategy.put_trace(opts[:trace_key], %{trace | stack: new_stack, spans: new_spans})

      {:error, _} = error ->
        error
    end
  end

  @spec finish_trace(Tracer.opts()) ::
          {:ok, Trace.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, [Optimal.error()]}
  def finish_trace(:disabled), do: {:error, :disabled}

  def finish_trace(opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:trace_key]) do
      {:error, :no_trace_context} = error ->
        Logger.error("Tried to finish a trace without an active trace.")
        error

      {:ok, %Trace{spans: spans, stack: stack} = trace} ->
        unfinished_spans = Enum.map(stack, &ensure_completion_time_set(&1, adapter))
        sender = opts[:sender] || adapter.default_sender()
        # TODO: We need to define a behaviour for the Sender API.
        sender.send_trace(%Trace{trace | spans: spans ++ unfinished_spans, stack: []})
        strategy.delete_trace(opts[:trace_key])

      {:error, _} = error ->
        error
    end
  end

  @spec finish_span(Tracer.opts()) ::
          {:ok, Span.t()}
          | {:error, :disabled}
          | {:error, :no_trace_context}
          | {:error, :no_span_context}
          | {:error, [Optimal.error()]}
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
        finished_span = ensure_completion_time_set(span, adapter)

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

  @spec current_span_id(Tracer.opts()) :: Spandex.id() | nil
  def current_span_id(:disabled), do: nil

  def current_span_id(opts) do
    case current_span(opts) do
      nil -> nil
      span -> span.id
    end
  end

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

  @spec continue_trace(String.t(), SpanContext.t(), Keyword.t()) ::
          {:ok, %Trace{}}
          | {:error, :disabled}
          | {:error, :trace_already_present}
          | {:error, [Optimal.error()]}
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

  @spec continue_trace(String.t(), Spandex.id(), Spandex.id(), Keyword.t()) ::
          {:ok, %Trace{}}
          | {:error, :disabled}
          | {:error, :trace_already_present}
          | {:error, [Optimal.error()]}
  @deprecated "Use continue_trace/3 instead"
  def continue_trace(_, _, _, :disabled), do: {:error, :disabled}

  def continue_trace(name, trace_id, span_id, opts) do
    continue_trace(name, %SpanContext{trace_id: trace_id, parent_id: span_id}, opts)
  end

  @spec continue_trace_from_span(String.t(), Span.t(), Tracer.opts()) ::
          {:ok, %Trace{}}
          | {:error, :disabled}
          | {:error, :trace_already_present}
          | {:error, [Optimal.error()]}
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

  @spec distributed_context(Plug.Conn.t(), Tracer.opts()) ::
          {:ok, map()}
          | {:error, atom()}
          | {:error, [Optimal.error()]}
  def distributed_context(_, :disabled), do: {:error, :disabled}

  def distributed_context(conn, opts) do
    adapter = opts[:adapter]
    adapter.distributed_context(conn, opts)
  end

  # Private Helpers

  defp do_continue_trace(name, span_context, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    with {:ok, top_span} <- span(name, opts, span_context, adapter) do
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
      Logger.metadata(span_id: span.id)
      {:ok, span}
    end
  end

  defp do_start_span(name, %Trace{stack: [], id: trace_id} = trace, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]
    span_context = %SpanContext{trace_id: trace_id}

    with {:ok, span} <- span(name, opts, span_context, adapter),
         {:ok, _trace} <- strategy.put_trace(opts[:trace_key], %{trace | stack: [span]}) do
      Logger.metadata(span_id: span.id)
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
    new_stack = List.update_at(stack, -1, &update_or_keep(&1, opts))

    with {:ok, _trace} <- strategy.put_trace(opts[:trace_key], %{trace | stack: new_stack}) do
      {:ok, Enum.at(new_stack, -1)}
    end
  end

  defp do_update_span(%Trace{stack: [current_span | other_spans]} = trace, opts, false) do
    strategy = opts[:strategy]
    updated_span = update_or_keep(current_span, opts)
    new_stack = [updated_span | other_spans]

    with {:ok, _trace} <- strategy.put_trace(opts[:trace_key], %{trace | stack: new_stack}) do
      {:ok, updated_span}
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
