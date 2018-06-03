defmodule Spandex.Adapters.Datadog do
  @moduledoc """
  A datadog APM implementation for spandex.
  """

  @behaviour Spandex.Adapters.Adapter

  require Logger

  @max_id 9_223_372_036_854_775_807

  @impl Spandex.Adapters.Adapter
  def trace_id(), do: :rand.uniform(@max_id)

  @impl Spandex.Adapters.Adapter
  def span_id(), do: trace_id()

  @impl Spandex.Adapters.Adapter
  def now(), do: :os.system_time(:nano_seconds)

  @impl Spandex.Adapters.Adapter
  def default_sender() do
    Spandex.Datadog.ApiServer
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
      _ -> nil
    end
  end

  defp parse_header(_header), do: nil
end
