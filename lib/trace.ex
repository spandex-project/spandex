defmodule Spandex.Trace do
  @moduledoc """
  Trace helpers for managing the process dictionary stored trace and span stack
  """
  @spec get_trace(map) :: map | nil
  def get_trace(default \\ nil) do
    Process.get(:spandex_trace, default)
  end

  @spec put_trace(map) :: :ok
  def put_trace(trace) do
    Process.put(:spandex_trace, trace)

    :ok
  end

  @spec start_trace(term, [term]) :: :ok
  def start_trace(id, stack \\ []) do
    put_trace(%{id: id, stack: stack, spans: []})
  end

  @spec start_span(term) :: :ok
  def start_span(span) do
    case get_trace() do
      nil ->
        {:error, :no_trace_context}
      trace = %{stack: stack} ->
        put_trace(%{trace | stack: [span | stack]})
    end
  end

  @spec delete_trace() :: :ok
  def delete_trace() do
    Logger.metadata([trace_id: nil, span_id: nil])
    Process.delete(:spandex_trace)

    :ok
  end

  @spec get_span() :: term | {:error, term}
  def get_span() do
    case get_trace() do
      nil ->
        {:error, :no_trace_context}
      %{stack: [span|_]} ->
        span
      _ -> {:error, :no_span_context}
    end
  end

  @spec update_span(((term) -> term)) :: :ok | {:error, atom}
  def update_span(func) do
    case get_trace() do
      nil ->
        {:error, :no_trace_context}
      trace = %{stack: stack} ->
        new_stack = List.update_at(stack, 0, func)

        put_trace(%{trace | stack: new_stack})

        :ok
    end
  end

  @spec update_top_span(((term) -> term)) :: :ok | {:error, atom}
  def update_top_span(func) do
    case get_trace() do
      nil ->
        {:error, :no_trace_context}
      trace = %{stack: stack} ->
        new_stack =
          stack
          |> Enum.reverse()
          |> List.update_at(0, func)
          |> Enum.reverse()

        put_trace(%{trace | stack: new_stack})

        :ok
    end
  end

  @spec finish_span(((term) -> term), Keyword.t()) :: :ok | {:error, atom}
  def finish_span(func, opts \\ []) do
    save? = Keyword.get(opts, :save?, true)
    case get_trace() do
      nil ->
        {:error, :no_trace_context}
      %{stack: []} ->
        {:error, :no_span_context}
      trace = %{stack: [span|stack_tail], spans: spans} ->
        if save? do
          put_trace(%{trace | stack: stack_tail, spans: [func.(span) | spans]})
        else
          func.(span)
          put_trace(%{trace | stack: stack_tail})
        end
    end
  end

  @spec finish_trace(((term) -> term), ((term) -> term)) :: term | {:error, atom}
  def finish_trace(stop_func, span_handler \\ &(&1)) do
    result =
      case get_trace() do
        nil -> {:error, :no_trace_context}
        %{stack: stack, spans: spans} ->
          stack
          |> Enum.map(stop_func)
          |> Kernel.++(spans)
          |> span_handler.()
      end

    delete_trace()

    result
  end
end
