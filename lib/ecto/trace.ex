defmodule Spandex.Ecto.Trace do
  @moduledoc """

  A trace builder that can be given to ecto as a logger. It will try to get
  the trace_id and span_id from the caller pid in the case that the particular
  query is being run asynchronously (as in the case of parallel preloads).

  Traces will default to the service name `:ecto` but can be configured:

  config :spandex, :ecto,
    service: :my_ecto

  To configure, set it up as an ecto logger like so:

  config :my_app, MyApp.Repo,
    loggers: [{Ecto.LogEntry, :log, [:info]}, {Spandex.Ecto.Trace, :trace, []}]

  """
  @default_service_name :ecto

  defmodule Error do
    defexception [:message]
  end

  def trace(log_entry) do
    config = config()
    span_level = config[:level]
    if !Spandex.disabled?() && Spandex.should_span?(span_level) do
      now = Spandex.Datadog.Utils.now()
      _ = setup(log_entry)
      query = string_query(log_entry)
      num_rows = num_rows(log_entry)

      queue_time = get_time(log_entry, :queue_time)
      query_time = get_time(log_entry, :query_time)
      decoding_time = get_time(log_entry, :decode_time)

      start = now - (queue_time + query_time + decoding_time)

      Spandex.update_span(
        %{
          start: start,
          completion_time: now,
          service: config[:service],
          resource: query,
          type: :db,
          meta: %{"sql.query" => query, "sql.rows" => inspect(num_rows)}
        }
      )

      _ = report_error(log_entry)

      if queue_time != 0 do
        _ = Spandex.start_span("queue")
        _ = Spandex.update_span(%{start: start, completion_time: start + queue_time})
        _ = Spandex.finish_span()
      end

      if query_time != 0 do
        _ = Spandex.start_span("run_query")
        _ = Spandex.update_span(%{start: start + queue_time, completion_time: start + queue_time + query_time})
        _ = Spandex.finish_span()
      end

      if decoding_time != 0 do
        _ = Spandex.start_span("decode")
        _ = Spandex.update_span(%{start: start + queue_time + query_time, completion_time: now})
        _ = Spandex.finish_span()
      end

      finish_ecto_trace(log_entry)
    end

    log_entry
  end

  defp finish_ecto_trace(%{caller_pid: caller_pid}) do
    if caller_pid != self() do
      Spandex.finish_trace()
    else
      Spandex.finish_span()
    end
  end
  defp finish_ecto_trace(_), do: :ok

  defp setup(%{caller_pid: caller_pid}) when is_pid(caller_pid) do
    if caller_pid == self() do
      Logger.metadata(trace_id: Spandex.current_trace_id(), span_id: Spandex.current_span_id())

      Spandex.start_span("query")
    else
      trace = Process.info(caller_pid)[:dictionary][:spandex_trace]

      if trace do
        trace_id = trace.id
        span_id =
          trace
          |> Map.get(:stack)
          |> Enum.at(0, %{})
          |> Map.get(:id)

        Logger.metadata(trace_id: trace_id, span_id: span_id)

        Spandex.continue_trace("query", trace_id, span_id)
      else
        Spandex.start_trace("query")
      end
    end
  end

  defp setup(_) do
    :ok
  end

  defp report_error(%{result: {:ok, _}}), do: :ok
  defp report_error(%{result: {:error, error}}) do
    Spandex.span_error(%Error{message: inspect(error)})
  end

  defp string_query(%{query: query}) when is_function(query), do: Macro.unescape_string(query.() || "")
  defp string_query(%{query: query}) when is_bitstring(query), do: Macro.unescape_string(query)
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

  defp config do
    :spandex
    |> Confex.get_env(:ecto, [])
    |> Keyword.put_new(:service, @default_service_name)
    |> Keyword.put_new(:level, Spandex.default_level())
  end
end
