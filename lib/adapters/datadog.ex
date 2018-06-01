defmodule Spandex.Adapters.Datadog do
  @moduledoc """
  A datadog APM implementation for spandex.
  """

  @behaviour Spandex.Adapters.Adapter

  alias Spandex.Datadog.Span
  alias Spandex.Datadog.Utils

  require Logger

  @doc """
  Starts a trace context in process local storage.
  """
  @impl Spandex.Adapters.Adapter
  @spec start_trace(String.t(), opts :: Keyword.t()) :: {:ok, term} | {:error, term}
  def start_trace(name, opts) do
    if get_trace() do
      _ = Logger.error("Tried to start a trace over top of another trace.")
      {:error, :trace_running}
    else
      trace_id = Utils.next_id()

      top_span =
        %{trace_id: trace_id, name: name}
        |> Span.new(opts)

      Logger.metadata(trace_id: trace_id)

      put_trace(%{id: trace_id, stack: [top_span], spans: [], start: Utils.now()})

      {:ok, trace_id}
    end
  end

  @doc """
  Starts a span and adds it to the span stack.
  """
  @impl Spandex.Adapters.Adapter
  @spec start_span(String.t(), opts :: Keyword.t()) :: {:ok, term} | {:error, term}
  def start_span(name, opts) do
    trace = get_trace(:undefined)

    case trace do
      :undefined ->
        {:error, :no_trace_context}

      %{stack: [current_span | _]} ->
        new_span = Span.child_of(current_span, name)

        put_trace(%{trace | stack: [new_span | trace.stack]})

        Logger.metadata(span_id: new_span.id)

        {:ok, new_span.id}

      _ ->
        new_span =
          %{trace_id: trace.id, name: name}
          |> Span.new(opts)

        put_trace(%{trace | stack: [new_span | trace.stack]})

        Logger.metadata(span_id: new_span.id)

        {:ok, new_span.id}
    end
  end

  @doc """
  Updates a span according to the provided context.
  See `Spandex.Datadog.Span.update/2` for more information.
  """
  @impl Spandex.Adapters.Adapter
  @spec update_span(map, Keyword.t()) :: :ok | {:error, term}
  def update_span(context, _opts) do
    trace = get_trace()

    if trace do
      new_stack =
        List.update_at(trace.stack, 0, fn span ->
          Span.update(span, context)
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
  @impl Spandex.Adapters.Adapter
  @spec update_top_span(map, Keyword.t()) :: :ok | {:error, term}
  def update_top_span(context, _opts) do
    trace = get_trace()

    if trace do
      new_stack =
        trace.stack
        |> Enum.reverse()
        |> List.update_at(0, fn span ->
          Span.update(span, context)
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
  @impl Spandex.Adapters.Adapter
  @spec update_all_spans(map, Keyword.t()) :: :ok | {}
  def update_all_spans(context, _opts) do
    trace = get_trace()

    if trace do
      new_stack = Enum.map(trace.stack, &Span.update(&1, context))
      new_spans = Enum.map(trace.spans, &Span.update(&1, context))

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
  @impl Spandex.Adapters.Adapter
  @spec finish_span(Keyword.t()) :: :ok | {:error, term}
  def finish_span(_opts) do
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
          |> Span.stop()

        put_trace(%{trace | stack: new_stack, spans: [completed_span | trace.spans]})

        :ok
    end
  end

  @doc """
  Sends the trace to datadog and clears out the current trace data
  """
  @impl Spandex.Adapters.Adapter
  @spec finish_trace(opts :: Keyword.t()) :: :ok | {:error, :no_trace_context}
  def finish_trace(opts) do
    trace = get_trace()
    sender = opts[:sender]

    if trace do
      unfinished_spans = Enum.map(trace.stack, &Span.stop/1)

      trace.spans
      |> Kernel.++(unfinished_spans)
      |> Enum.map(&Span.stop/1)
      |> Enum.map(&Span.to_map(&1, opts))
      |> sender.send_spans()

      delete_trace()

      :ok
    else
      {:error, :no_trace_context}
    end
  end

  @doc """
  Gets the current trace id
  """
  @impl Spandex.Adapters.Adapter
  @spec current_trace_id(Keyword.t()) :: term | nil | {:error, term}
  def current_trace_id(_opts) do
    %{id: id} = get_trace(%{id: nil})
    id
  end

  @doc """
  Gets the current span id
  """
  @impl Spandex.Adapters.Adapter
  @spec current_span_id(Keyword.t()) :: term | nil | {:error, term}
  def current_span_id(_opts) do
    case get_trace() do
      %{stack: [%{id: current_span_id} | _]} ->
        current_span_id

      _ ->
        nil
    end
  end

  @doc """
  Gets the current span
  """
  @impl Spandex.Adapters.Adapter
  @spec current_span(Keyword.t()) :: term | nil | {:error, term}
  def current_span(_opts) do
    case get_trace() do
      %{stack: [span | _]} ->
        span

      _ ->
        nil
    end
  end

  @doc """
  Continues a trace given a name and a span
  """
  @impl Spandex.Adapters.Adapter
  @spec continue_trace_from_span(String.t(), term, Keyword.t()) :: {:ok, term}
  def continue_trace_from_span(name, %{trace_id: trace_id} = span, opts) do
    put_trace(%{id: trace_id, stack: [span], spans: [], start: Utils.now()})

    start_span(name, opts)
  end

  @doc """
  Continues a trace given a name, a trace_id and a span_id
  """
  @impl Spandex.Adapters.Adapter
  @spec continue_trace(String.t(), term, term, Keyword.t()) :: {:ok, term} | {:error, term}
  def continue_trace(name, trace_id, span_id, opts) when is_integer(trace_id) and is_integer(span_id) do
    trace = get_trace(:undefined)

    cond do
      trace == :undefined ->
        top_span =
          %{trace_id: trace_id, parent_id: span_id, name: name}
          |> Span.new(opts)

        put_trace(%{id: trace_id, stack: [top_span], spans: [], start: Utils.now()})
        {:ok, trace_id}

      trace_id == trace.id ->
        start_span(name, opts)

      true ->
        {:error, :trace_already_present}
    end
  end

  @doc """
  Attaches error data to the current span, and marks it as an error.
  """
  @impl Spandex.Adapters.Adapter
  @spec span_error(Exception.t(), Keyword.t()) :: :ok | {:error, term}
  def span_error(%{__struct__: type} = exception, opts) do
    message = Exception.message(exception)
    stacktrace = Exception.format_stacktrace(System.stacktrace())

    update_span(
      %{error: 1, error_message: message, stacktrace: stacktrace, error_type: type},
      opts
    )
  end

  @doc """
  Fetches the datadog trace & parent IDs from the conn request headers
  if they are present.
  """
  @impl Spandex.Adapters.Adapter
  @spec distributed_context(conn :: Plug.Conn.t(), Keyword.t()) ::
          {:ok, %{trace_id: binary, parent_id: binary}} | {:error, :no_trace_context}
  def distributed_context(%Plug.Conn{} = conn, _opts) do
    trace_id = get_first_header(conn, "x-datadog-trace-id")
    parent_id = get_first_header(conn, "x-datadog-parent-id")

    if is_nil(trace_id) || is_nil(parent_id) do
      {:error, :no_distributed_trace}
    else
      {:ok, %{trace_id: trace_id, parent_id: parent_id}}
    end
  end

  @spec get_first_header(conn :: Plug.Conn.t(), header_name :: binary) :: binary | nil
  defp get_first_header(conn, header_name) do
    conn
    |> Plug.Conn.get_req_header(header_name)
    |> List.first()
    |> parse_header()
  end

  defp parse_header(header) when is_bitstring(header) do
    case Integer.parse(header) do
      {int, _} -> int
      _        -> nil
    end
  end

  defp parse_header(_header), do: nil

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
    Logger.metadata(trace_id: nil, span_id: nil)
    Process.delete(:spandex_trace)
  end
end
