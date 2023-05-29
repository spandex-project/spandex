defmodule Spandex.TestAdapter do
  @moduledoc false
  @behaviour Spandex.Adapter

  require Logger
  alias Spandex.SpanContext

  @max_id 9_223_372_036_854_775_807

  @impl Spandex.Adapter
  def trace_id, do: :rand.uniform(@max_id)

  @impl Spandex.Adapter
  def span_id, do: trace_id()

  @impl Spandex.Adapter
  def now, do: :os.system_time(:nano_seconds)

  @impl Spandex.Adapter
  def default_sender, do: Spandex.TestSender

  @impl Spandex.Adapter
  def default_priority, do: 1

  @doc """
  Fetches the test trace & parent IDs from the conn request headers
  if they are present.
  """
  @impl Spandex.Adapter
  @spec distributed_context(conn :: Plug.Conn.t(), Tracer.opts()) ::
          {:ok, SpanContext.t()}
          | {:error, :no_distributed_trace}
  def distributed_context(%Plug.Conn{} = conn, _opts) do
    trace_id = get_first_header(conn, "x-test-trace-id")
    parent_id = get_first_header(conn, "x-test-parent-id")
    priority = get_first_header(conn, "x-test-sampling-priority")

    if is_nil(trace_id) || is_nil(parent_id) do
      {:error, :no_distributed_trace}
    else
      {:ok, %SpanContext{trace_id: trace_id, parent_id: parent_id, priority: priority}}
    end
  end

  @impl Spandex.Adapter
  @spec distributed_context(headers :: Spandex.headers(), Tracer.opts()) ::
          {:ok, SpanContext.t()}
          | {:error, :no_distributed_trace}
  def distributed_context(headers, _opts) when is_list(headers) do
    trace_id = get_first_header(headers, "x-test-trace-id")
    parent_id = get_first_header(headers, "x-test-parent-id")
    priority = get_first_header(headers, "x-test-sampling-priority")

    if is_nil(trace_id) || is_nil(parent_id) do
      {:error, :no_distributed_trace}
    else
      {:ok, %SpanContext{trace_id: trace_id, parent_id: parent_id, priority: priority}}
    end
  end

  def distributed_context(headers, _opts) when is_map(headers) do
    %{
      "x-test-trace-id" => trace_id,
      "x-test-parent-id" => parent_id,
      "x-test-sampling-priority" => priority
    } = headers

    if is_nil(trace_id) || is_nil(parent_id) do
      {:error, :no_distributed_trace}
    else
      {:ok, %SpanContext{trace_id: trace_id, parent_id: parent_id, priority: priority}}
    end
  end

  @doc """
  Injects test HTTP headers to represent the specified SpanContext
  """
  @impl Spandex.Adapter
  @spec inject_context(Spandex.headers(), SpanContext.t(), Tracer.opts()) :: Spandex.headers()
  def inject_context(headers, %SpanContext{} = span_context, _opts) when is_list(headers) do
    span_context
    |> tracing_headers()
    |> Kernel.++(headers)
  end

  def inject_context(headers, %SpanContext{} = span_context, _opts) when is_map(headers) do
    span_context
    |> tracing_headers()
    |> Enum.into(%{})
    |> Map.merge(headers)
  end

  # Private Helpers

  defp get_first_header(headers, key) when is_list(headers) do
    headers
    |> get_header(key)
    |> List.first()
  end

  defp get_first_header(conn, header_name) do
    conn
    |> Plug.Conn.get_req_header(header_name)
    |> List.first()
    |> parse_header()
  end

  defp get_header(headers, key) do
    for {^key, value} <- headers, do: value
  end

  defp parse_header(header) when is_bitstring(header) do
    case Integer.parse(header) do
      {int, _} -> int
      _ -> nil
    end
  end

  defp parse_header(_header), do: nil

  defp tracing_headers(%SpanContext{trace_id: trace_id, parent_id: parent_id} = span_context) do
    [
      {"x-test-trace-id", to_string(trace_id)},
      {"x-test-parent-id", to_string(parent_id)}
    ] ++ priority_header(span_context)
  end

  defp priority_header(%SpanContext{priority: nil}) do
    []
  end

  defp priority_header(%SpanContext{priority: priority}) do
    [{"x-test-sampling-priority", to_string(priority)}]
  end
end
