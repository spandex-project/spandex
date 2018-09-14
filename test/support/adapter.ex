defmodule Spandex.TestAdapter do
  @moduledoc false
  @behaviour Spandex.Adapter

  require Logger
  alias Spandex.SpanContext

  @max_id 9_223_372_036_854_775_807

  @impl Spandex.Adapter
  def trace_id(), do: :rand.uniform(@max_id)

  @impl Spandex.Adapter
  def span_id(), do: trace_id()

  @impl Spandex.Adapter
  def now(), do: :os.system_time(:nano_seconds)

  @impl Spandex.Adapter
  def default_sender() do
    Spandex.TestSender
  end

  @doc """
  Fetches the test trace & parent IDs from the conn request headers
  if they are present.
  """
  @impl Spandex.Adapter
  @spec distributed_context(conn :: Plug.Conn.t(), Keyword.t()) ::
          {:ok, SpanContext.t()}
          | {:error, :no_distributed_trace}
  def distributed_context(%Plug.Conn{} = conn, _opts) do
    trace_id = get_first_header(conn, "x-test-trace-id")
    parent_id = get_first_header(conn, "x-test-parent-id")
    # We default the priority to 1 so that we capture all traces by default until we implement trace sampling
    priority = get_first_header(conn, "x-test-sampling-priority") || 1

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
  def inject_context(headers, %SpanContext{trace_id: trace_id, parent_id: parent_id, priority: priority}, _opts) do
    [
      {"x-test-trace-id", to_string(trace_id)},
      {"x-test-parent-id", to_string(parent_id)},
      {"x-test-sampling-priority", to_string(priority)}
    ] ++ headers
  end

  # Private Helpers

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
      _ -> nil
    end
  end

  defp parse_header(_header), do: nil
end
