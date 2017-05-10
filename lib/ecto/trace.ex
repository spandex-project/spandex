defmodule Spandex.Ecto.Trace do
  require Spandex.Trace

  def trace(log_entry) do
    now = Spandex.Span.now()
    if setup(log_entry) == :ok do
      query = string_query(log_entry)
      num_rows = num_rows(log_entry)

      queue_time = get_time(log_entry, :queue_time)
      query_time = get_time(log_entry, :query_time)
      decoding_time = get_time(log_entry, :decode_time)

      Spandex.Trace.span("query") do
        start = now - (queue_time + query_time + decoding_time)
        _ = report_error(log_entry)
        Spandex.Trace.update_span(
          %{
            start: start,
            completion_time: now,
            service: :ecto,
            meta: %{"sql.query" => inspect(query), "sql.rows" => inspect(num_rows)}
          }
        )

        if queue_time do
          Spandex.Trace.span("queue") do
            Spandex.Trace.update_span(%{start: start, completion_time: start + queue_time})
          end
        end

        if query_time do
          Spandex.Trace.span("run_query") do
            Spandex.Trace.update_span(%{start: start + queue_time, completion_time: start + queue_time + query_time})
          end
        end

        if decoding_time do
          Spandex.Trace.span("decode") do
            Spandex.Trace.update_span(%{start: start + queue_time + query_time, completion_time: now})
          end
        end
      end
    end
  end

  defp setup(%{caller_pid: caller_pid}) when is_pid(caller_pid) do
    if caller_pid == self() do
      :ok
    else
      trace_pid =
        :spandex_trace
        |> :ets.lookup(caller_pid)
        |> Enum.at(0)
        |> Kernel.||({nil, nil})
        |> elem(1)

      if trace_pid do
        _ = :ets.insert(:spandex_trace, {self(), trace_pid})
        :ok
      else
        :no_trace
      end
    end
  end

  defp setup(_) do
    trace_pid =
      :spandex_trace
      |> :ets.lookup(self())
      |> Enum.at(0)
      |> Kernel.||({nil, nil})
      |> elem(1)

    if trace_pid do
      :ok
    else
      :no_trace
    end
  end

  defp report_error(%{result: {:ok, _}}), do: :ok
  defp report_error(%{result: _}) do
    Spandex.Trace.update_span(%{error: 1})
    :ok
  end

  defp string_query(%{query: query}) when is_function(query), do: query.()
  defp string_query(%{query: query}) when is_bitstring(query), do: query
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
