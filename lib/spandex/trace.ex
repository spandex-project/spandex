defmodule Spandex.Trace do
  use GenServer

  require Logger

  def start_link(opts \\ []) do
    server_state = setup_state(opts)
    GenServer.start_link(
      __MODULE__,
      server_state,
      name: server_state[:name]
    )
  end

  def init(state) do
    kill_me_in(state[:ttl_seconds])
    {:ok, state}
  end

  def span(name, type, trace_pid, parent, func), do: do_span(name, type, trace_pid, func, parent)
  def span(name, type, trace_pid, func), do: do_span(name, type, trace_pid, func, nil)

  def publish(trace_pid) do
    GenServer.cast(trace_pid, :publish)
    GenServer.stop(trace_pid)
  end

  def update(trace_pid, attribute, value) do
    GenServer.cast(trace_pid, {:update, attribute, value})
  end

  defp do_span(name, type, trace_pid, func, parent) do
    start = DateTime.utc_now |> DateTime.to_unix(:nanoseconds)
    span_id = trace_id()

    case try_span(func, span_id) do
      {:ok, return_value} ->
        duration = (DateTime.utc_now |> DateTime.to_unix(:nanoseconds)) - start
        GenServer.cast(trace_pid, {:add_span, span_id, type, name, start, duration, parent})
        return_value
      {:error, exception} ->
        duration = (DateTime.utc_now |> DateTime.to_unix(:nanoseconds)) - start
        GenServer.cast(trace_pid, {:add_error_span, span_id, type, name, start, duration, parent, exception})
        GenServer.cast(trace_pid, :publish)
        raise exception
    end
  end

  defp try_span(func, span_id) do
    {:ok, func.(span_id)}
  rescue
    exception -> {:error, exception}
  end

  defp kill_me_in(seconds) do
    spawn_link fn ->
      :timer.sleep(seconds * 1000)
      Process.exit(self(), :kill)
    end
  end

  defp setup_state(opts) do
    trace_id = trace_id()
    opts
    |> Enum.into(%{})
    |> Map.put_new(:trace_id, trace_id)
    |> Map.put_new(:resource, "unknown")
    |> Map.put_new(:service, Application.get_env(:spandex, :service, "unknown"))
    |> Map.put_new(:process_name, :"Spandex.Trace:#{trace_id}")
    |> Map.put_new(:ttl_seconds, Application.get_env(:spandex, :ttl_seconds, 30))
    |> Map.put_new(:host, Application.get_env(:spandex, :host, "localhost"))
    |> Map.put_new(:port, port(Application.get_env(:spandex, :port, 8126)))
    |> Map.put_new(:info_logs, Application.get_env(:spandex, :info_logs, false))
    |> Map.put_new(:error_logs, Application.get_env(:spandex, :error_logs, true))
    |> Map.put_new(:env, Application.get_env(:spandex, :env, "unknown"))
    |> Map.put_new(:top_level_span_type, Application.get_env(:spandex, :top_level_span_type, "web"))
    |> Map.put_new(:trace_start, DateTime.utc_now |> DateTime.to_unix(:nanoseconds))
    |> Map.put_new(:top_level_span_id, trace_id())
    |> Map.put_new(:trace_name, "top")
    |> Map.put_new(:spans, [])
  end

  defp trace_id(), do: :rand.uniform(9223372036854775807)

  # Callbacks
  def handle_cast(:publish, state) do
    do_publish(state)
    {:noreply, state}
  end

  def handle_cast({:update, attribute, value}, state = %{spans: spans}) do
    new_state = %{state | spans: Enum.map(spans, &update_attribute(&1, attribute, value))}

    {:noreply, Map.put(new_state, attribute, value)}
  end

  def handle_cast(
    {:add_span, span_id, type, name, start, duration, parent_id},
    state = %{spans: spans, top_level_span_id: top_level_span_id})
  do
    new_span = span_json(span_id, name, type, start, duration, state, parent_id || top_level_span_id)
    log_info(state, fn -> "Adding span #{inspect new_span}" end)
    new_state = %{state | spans: [ new_span | spans]}
    {:noreply, new_state}
  end

  def handle_cast(
    {:add_error_span, span_id, type, name, start, duration, parent_id, exception},
    state = %{spans: spans, top_level_span_id: top_level_span_id})
  do
    message = Exception.message(exception)
    stacktrace = Exception.format_stacktrace(System.stacktrace())
    new_span =
      span_id
      |> span_json(name, type, start, duration, state, parent_id || top_level_span_id)
      |> Map.put_new(:meta, %{})
      |> put_in([:meta, :message], message)
      |> put_in([:meta, :stacktrace], stacktrace)
      |> Map.put(:error, 1)

    log_info(state, fn -> "Adding error span #{inspect new_span}" end)

    {:noreply, %{state | spans: [new_span | spans]}}
  end

  defp span_json(id, name, type, start, duration, state, parent_id) do
    %{
      trace_id: state[:trace_id],
      span_id: id,
      name: name,
      resource: state[:resource],
      service: state[:service],
      type: type,
      start: start,
      duration: duration,
      parent_id: parent_id,
      meta: %{
        env: state[:env]
      }
    }
  end

  defp update_attribute(span, :env, value) do
    span
    |> Map.put_new(:meta, %{})
    |> put_in([:meta, :env], value)
  end

  defp update_attribute(span, attribute, value) do
    Map.put(span, attribute, value)
  end

  defp do_publish(state = %{
  spans: spans, host: host, port: port, trace_start: trace_start,
  top_level_span_id: top_level_span_id, top_level_span_type: top_level_span_type, trace_name: trace_name
  }) do
    trace_duration = (DateTime.utc_now |> DateTime.to_unix(:nanoseconds)) - trace_start
    parent_span = span_json(top_level_span_id, trace_name, top_level_span_type, trace_start, trace_duration, state, nil)
    all_traces = [[parent_span | spans]]
    json = Poison.encode!(all_traces)
    case HTTPoison.put "#{host}:#{port}/v0.3/traces", json, [{"Content-Type", "application/json"}] do
      {:ok, _} -> :ok
      {:error, body} -> log_error(state, fn -> "Attempted to publish `#{inspect json}` to datadog APM, but received error response: `#{inspect body}`" end)
    end
  end

  defp log_error(state, func) do
    if state[:error_logs] do
      Logger.error(func)
    else
      :ok
    end
  end

  def log_info(state, func) do
    if state[:info_logs] do
      Logger.info(func)
    else
      :ok
    end
  end

  defp port(string) when is_bitstring(string), do: String.to_integer(string)
  defp port(integer) when is_integer(integer), do: integer
end
