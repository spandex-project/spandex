defmodule Spandex do
  @moduledoc """
  The functions here call the corresponding functions on the configured adapter.
  """
  require Logger

  alias Spandex.Span
  alias Spandex.Trace

  def start_trace(_, :disabled), do: {:error, :disabled}

  def start_trace(name, opts) do
    strategy = opts[:strategy]

    if strategy.get_trace(opts[:tracer]) do
      _ = Logger.error("Tried to start a trace over top of another trace.")
      {:error, :trace_running}
    else
      adapter = opts[:adapter]
      trace_id = adapter.trace_id()

      name
      |> span(opts, trace_id, adapter)
      |> with_span(fn span ->
        Logger.metadata(trace_id: trace_id, span_id: span.id)

        trace = %Trace{
          spans: [],
          stack: [span],
          id: trace_id
        }

        strategy.put_trace(opts[:tracer], trace)
      end)
    end
  end

  def start_span(_, :disabled), do: {:error, :disabled}

  def start_span(name, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        {:error, :no_trace_context}

      %Trace{stack: [current_span | _]} = trace ->
        current_span
        |> Span.child_of(name, adapter.span_id(), adapter.now(), opts)
        |> with_span(fn span ->
          strategy.put_trace(opts[:tracer], %{trace | stack: [span | trace.stack]})

          Logger.metadata(span_id: span.id)

          {:ok, span}
        end)

      %Trace{stack: [], id: trace_id} = trace ->
        name
        |> span(opts, trace_id, adapter)
        |> with_span(fn span ->
          strategy.put_trace(opts[:tracer], %{trace | stack: [span]})

          Logger.metadata(span_id: span.id)

          {:ok, span}
        end)
    end
  end

  def update_span(opts, top? \\ false)
  def update_span(:disabled, _), do: {:error, :disabled}

  def update_span(opts, top?) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        {:error, :no_trace_context}

      %Trace{stack: stack} = trace ->
        index =
          if top? do
            -1
          else
            0
          end

        new_stack = List.update_at(stack, index, &update_or_keep(&1, opts))

        strategy.put_trace(opts[:tracer], %{trace | stack: new_stack})

        {:ok, Enum.at(new_stack, index)}
    end
  end

  def update_top_span(:disabled), do: {:error, :disabled}

  def update_top_span(opts) do
    top? = true
    update_span(opts, top?)
  end

  def update_all_spans(:disabled), do: {:error, :disabled}

  def update_all_spans(opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        {:error, :no_trace_context}

      %Trace{stack: stack, spans: spans} = trace ->
        new_stack = Enum.map(stack, &update_or_keep(&1, opts))

        new_spans = Enum.map(spans, &update_or_keep(&1, opts))

        strategy.put_trace(opts[:tracer], %{trace | stack: new_stack, spans: new_spans})
    end
  end

  def finish_trace(:disabled), do: {:error, :disabled}

  def finish_trace(opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        {:error, :no_trace_context}

      %Trace{spans: spans, stack: stack} ->
        unfinished_spans = Enum.map(stack, &ensure_completion_time_set(&1, adapter))

        sender = opts[:sender] || adapter.default_sender()

        spans
        |> Kernel.++(unfinished_spans)
        |> sender.send_spans()

        strategy.delete_trace(opts[:tracer])
    end
  end

  def finish_span(:disabled), do: {:error, :disabled}

  def finish_span(opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        {:error, :no_trace_context}

      %Trace{stack: []} ->
        {:error, :no_span_context}

      %Trace{stack: [span | tail], spans: spans} = trace ->
        finished_span = ensure_completion_time_set(span, adapter)

        strategy.put_trace(opts[:tracer], %{trace | stack: tail, spans: [finished_span | spans]})
        {:ok, finished_span}
    end
  end

  defp ensure_completion_time_set(%Span{completion_time: nil} = span, adapter) do
    update_or_keep(span, completion_time: adapter.now())
  end

  defp ensure_completion_time_set(%Span{} = span, _adapter), do: span

  def span_error(_error, _stacktrace, :disabled), do: {:error, :disabled}

  def span_error(exception, stacktrace, opts) do
    updates = [exception: exception, stacktrace: stacktrace]

    update_span(Keyword.put_new(opts, :error, updates))
  end

  def current_trace_id(:disabled), do: nil

  def current_trace_id(opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        nil

      %Trace{id: id} ->
        id
    end
  end

  def current_span_id(:disabled), do: nil

  def current_span_id(opts) do
    case current_span(opts) do
      nil -> nil
      span -> span.id
    end
  end

  def current_span(:disabled), do: nil

  def current_span(opts) do
    strategy = opts[:strategy]

    case strategy.get_trace(opts[:tracer]) do
      nil -> nil
      %Trace{stack: []} -> nil
      %Trace{stack: [span | _]} -> span
    end
  end

  def continue_trace(_, _, _, :disabled), do: {:error, :disabled}

  def continue_trace(name, trace_id, span_id, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        opts_with_parent = Keyword.put(opts, :parent_id, span_id)
        top_span = span(name, opts_with_parent, trace_id, adapter)

        strategy.put_trace(opts[:tracer], %Trace{id: trace_id, stack: [top_span], spans: []})

      _ ->
        {:error, :trace_already_present}
    end
  end

  def continue_trace_from_span(_name, _span, :disabled), do: {:error, :disabled}

  def continue_trace_from_span(name, span, opts) do
    strategy = opts[:strategy]
    adapter = opts[:adapter]

    case strategy.get_trace(opts[:tracer]) do
      nil ->
        span
        |> Span.child_of(name, adapter.span_id(), adapter.now(), opts)
        |> with_span(fn span ->
          strategy.put_trace(opts[:tracer], %Trace{
            id: adapter.trace_id(),
            stack: [span],
            spans: []
          })
        end)

      _ ->
        {:error, :trace_already_present}
    end
  end

  def distributed_context(_, :disabled), do: {:error, :disabled}

  def distributed_context(conn, opts) do
    adapter = opts[:adapter]
    adapter.distributed_context(conn, opts)
  end

  defp span(name, opts, trace_id, adapter) do
    opts
    |> Keyword.put_new(:name, name)
    |> Keyword.put(:trace_id, trace_id)
    |> Keyword.put(:start, adapter.now())
    |> Keyword.put(:id, adapter.span_id())
    |> Span.new()
  end

  defp update_or_keep(span, opts) do
    case Span.update(span, opts) do
      {:error, _} -> span
      span -> span
    end
  end

  def with_span({:error, errors}, _fun), do: {:error, errors}
  def with_span(span, fun), do: fun.(span)
end
