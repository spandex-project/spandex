defmodule Spandex.Ecto.Trace do
  defmodule Error do
    defexception [:message]
  end

  def trace(log_entry) do
    adapter = Confex.get(:spandex, :adapter)

    now = adapter.now()
    _ = setup(adapter, log_entry)
    query = string_query(log_entry)
    num_rows = num_rows(log_entry)

    queue_time = get_time(log_entry, :queue_time)
    query_time = get_time(log_entry, :query_time)
    decoding_time = get_time(log_entry, :decode_time)

    adapter.start_span("query")

    start = now - (queue_time + query_time + decoding_time)
    _ = report_error(adapter, log_entry)
    adapter.update_span(
      %{
        start: start,
        completion_time: now,
        service: :ecto,
        resource: query,
        meta: %{"sql.query" => query, "sql.rows" => inspect(num_rows)}
      }
    )

    if queue_time != 0 do
      _ = adapter.start_span("queue")
      _ = adapter.update_span(%{start: start, completion_time: start + queue_time})
      _ = adapter.finish_span()
    end

    if query_time != 0 do
      _ = adapter.start_span("run_query")
      _ = adapter.update_span(%{start: start + queue_time, completion_time: start + queue_time + query_time})
      _ = adapter.finish_span()
    end

    if decoding_time != 0 do
      _ = adapter.start_span("decode")
      _ = adapter.update_span(%{start: start + queue_time + query_time, completion_time: now})
      _ = adapter.finish_span()
    end

    finish_ecto_trace(adapter, log_entry)
  end

  defp finish_ecto_trace(adapter, %{caller_pid: caller_pid}) do
    if caller_pid != self() do
      adapter.finish_trace()
    else
      :ok
    end
  end
  defp finish_ecto_trace(_, _), do: :ok

  defp setup(adapter, %{caller_pid: caller_pid}) when is_pid(caller_pid) do
    adapter.continue_trace("query", caller_pid)
  end

  defp setup(_, _) do
    :ok
  end

  defp report_error(_adapter, %{result: {:ok, _}}), do: :ok
  defp report_error(adapter, %{result: {:error, error}}) do
    adapter.span_error(%Error{message: inspect(error)})
  end

  defp string_query(%{query: query}) when is_function(query), do: Macro.unescape_string(query.() || "")
  defp string_query(%{query: query}) when is_bitstring(query), do: Macro.unescape_string(query || "")
  defp string_query(_), do: ""

  defp num_rows(%{result: {:ok, %{num_rows: num_rows}}}), do: num_rows
  defp num_rows(_), do: 0

  def get_time(log_entry, key) do
    value = Map.get(log_entry, key)
    if is_integer(value) do
      to_nanoseconds(value)
    else
      0
    end
  end

  defp to_nanoseconds(time), do: System.convert_time_unit(time, :native, :nanoseconds)
end
