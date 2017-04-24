defmodule Spandex.Trace do
  @moduledoc """
  Examples:

  require Spandex.Trace
  alias Spandex.Trace

  trace = Trace.start(service: "my_service")

  defmodule Thing do
    require Spandex.Trace
    alias Spandex.Trace

    def trace_me(tracer) do
      Trace.span(tracer) do
        :timer.sleep(500)
      end
    end
  end

  Trace.span(trace, "foo") do
    Trace.update_span(trace, %{
      service: "mandark",
      resource: "mandark",
      type: "web",
      env: "test",

    })

    Thing.trace_me(trace)

    Trace.span(trace, "bar", fn _ ->
      :timer.sleep(1000)
    end)
  end

  Trace.publish(trace)
  """
  use GenServer

  def start(opts \\ []) do
    if Application.get_env(:spandex, :disabled?) do
      :disabled
    else
      server_state = setup_state(opts)
      GenServer.start(
        __MODULE__,
        server_state,
        name: server_state[:name]
      )
    end
  end

  def init(state) do
    kill_me_in(state[:ttl_seconds])
    {:ok, state}
  end

  defmacro span(tracer, name, do: block) do
    if Application.get_env(:spandex, :disabled?) do
      quote do
        _ = unquote(tracer)
        _ = unquote(name)
        unquote(block)
      end
    else
      quote do
        trace_pid = Spandex.Trace.get_trace_pid(unquote(tracer))
        if trace_pid do
          name = unquote(name)
          _ = Spandex.Trace.start_span(trace_pid, name)
          try do
            return_value = unquote(block)
            Spandex.Trace.end_span(trace_pid)
            return_value
          rescue
            exception ->
              Spandex.Trace.span_error(trace_pid, exception)
            raise exception
          end
        else
          unquote(block)
        end
      end
    end
  end

  defmacro span(tracer, name, func) do
    if Application.get_env(:spandex, :disabled?) do
      quote do
        unquote(func).(unquote(tracer))
      end
    else
      quote do
        tracer = unquote(tracer)
        trace_pid = Spandex.Trace.get_trace_pid(unquote(tracer))
        if trace_pid do
          name = unquote(name)
          _ = Spandex.Trace.start_span(trace_pid, name)
          try do
            return_value = unquote(func).(tracer)
            Spandex.Trace.end_span(trace_pid)
            return_value
          rescue
            exception ->
              Spandex.Trace.span_error(trace_pid, exception)
            raise exception
          end
        else
          unquote(func).(unquote(tracer))
        end
      end
    end
  end

  defmacro span(tracer, rest) do
    quote do
      Spandex.Trace.span(unquote(tracer), unquote(query_name(__CALLER__)), unquote(rest))
    end
  end

  @spec query_name(map) :: String.t
  defp query_name(%{function: {function, arity}, module: module}) do
    function_name = Atom.to_string(function)

    "#{inspect(module)}.#{function_name}/#{arity}"
  end

  def get_trace_pid({:ok, trace_pid}) when is_pid(trace_pid), do: trace_pid
  def get_trace_pid(%{trace: trace_pid}) when is_pid(trace_pid), do: trace_pid
  def get_trace_pid(trace_pid) when is_pid(trace_pid), do: trace_pid
  def get_trace_pid(%{trace: trace}), do: get_trace_pid(trace)
  def get_trace_pid(%{assigns: trace}), do: get_trace_pid(trace)
  def get_trace_pid(_), do: nil

  def publish(tracer) do
    trace_pid = get_trace_pid(tracer)
    if !Application.get_env(:spandex, :disabled?) && trace_pid do
      GenServer.cast(trace_pid, {:publish, Spandex.Span.now()})
      GenServer.stop(trace_pid)
    end
    tracer
  rescue
    _exception -> tracer
  end

  def start_span(tracer, name) do
    trace_pid = get_trace_pid(tracer)
    GenServer.cast(trace_pid, {:start_span, name, Spandex.Span.now()})
  end

  def end_span(tracer) do
    trace_pid = get_trace_pid(tracer)
    GenServer.cast(trace_pid, {:end_span, Spandex.Span.now()})
  end

  def update_span(tracer, update, override? \\ true) do
    trace_pid = get_trace_pid(tracer)
    GenServer.cast(trace_pid, {:update_span, update, override?})
  end

  def update_span_branch(tracer, update, override? \\ true) do
    trace_pid = get_trace_pid(tracer)
    GenServer.cast(trace_pid, {:update_span_branch, update, override?})
  end

  def update_all_spans(tracer, update, override? \\ true) do
    trace_pid = get_trace_pid(tracer)
    GenServer.cast(trace_pid, {:update_all_spans, update, override?})
  end

  def span_error(tracer, exception) do
    trace_pid = get_trace_pid(tracer)
    message = Exception.message(exception)
    stacktrace = Exception.format_stacktrace(System.stacktrace)
    type = exception.__struct__

    update_span_branch(trace_pid, %{error: 1, error_message: message, stacktrace: stacktrace, error_type: type})
    end_span(trace_pid)
  end

  defp do_publish(%{spans: spans, host: host, port: port, init_span: init_span}) do
    all_spans =
      spans
      |> Map.values
      |> Enum.map(&Spandex.Span.to_json/1)

    json = Poison.encode!([[Spandex.Span.to_json(init_span) | all_spans]])
    case HTTPoison.put "#{host}:#{port}/v0.3/traces", json |> IO.inspect, [{"Content-Type", "application/json"}] do
      {:ok, body} -> {:ok, body}
      {:error, body} -> {:error, body}
    end
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
    |> Map.put_new(:resource, Application.get_env(:spandex, :resource, "unknown"))
    |> Map.put_new(:service, Application.get_env(:spandex, :service, "unknown"))
    |> Map.put_new(:ttl_seconds, Application.get_env(:spandex, :ttl_seconds, 30))
    |> Map.put_new(:host, Application.get_env(:spandex, :host, "localhost"))
    |> Map.put_new(:port, port(Application.get_env(:spandex, :port, 8126)))
    |> Map.put_new(:env, Application.get_env(:spandex, :env, "unknown"))
    |> Map.put_new(:type, Application.get_env(:spandex, :type, "web"))
    |> Map.put_new(:process_name, :"Spandex.Trace:#{trace_id}")
    |> Map.put_new(:trace_id, trace_id)
    |> Map.put_new(:spans, %{})
    |> Map.put_new(:init_span, nil)
    |> Map.put(:span_stack, [])
    |> init_span
  end

  defp trace_id(), do: :rand.uniform(9223372036854775807)

  defp port(string) when is_bitstring(string), do: String.to_integer(string)
  defp port(integer) when is_integer(integer), do: integer

  defp init_span(state) do
    init_span = %Spandex.Span{
      id: trace_id(),
      trace_id: state[:trace_id],
      resource: state[:resource],
      service: state[:service],
      env: state[:env],
      type: state[:type],
      name: "Initialization"
    }
    |> Spandex.Span.begin(nil)

    %{state | init_span: init_span}
  end

  defp new_span(name, state, time) do
    parent_id = Enum.at(state[:span_stack], 0)

    if parent_id do
      state
      |> Map.get(:spans)
      |> Map.get(parent_id)
      |> Spandex.Span.child_of(name, trace_id())
      |> Spandex.Span.begin(time)
    else
      %Spandex.Span{
        id: trace_id(),
        trace_id: state[:trace_id],
        resource: state[:resource],
        service: state[:service],
        env: state[:env],
        type: state[:type],
        name: name
      }
      |> Spandex.Span.begin(time)
    end
  end

  defp put_span(state = %{spans: spans, span_stack: stack}, span = %{id: id}) do
    %{state | spans: Map.put(spans, id, span), span_stack: [id | stack]}
  end

  defp complete_span(state, time) do
    state
    |> edit_span(%{completion_time: time || Spandex.Span.now()}, false)
    |> pop_span
  end

  defp edit_span(state = %{spans: spans, span_stack: stack}, update, override?) do
    span_id = Enum.at(stack, 0)
    if spans[span_id] do
      updated_spans = Map.update!(spans, span_id, &Spandex.Span.update(&1, update, override?))

      Map.put(state, :spans, updated_spans)
    else
      state
    end
  end

  defp edit_span_branch(state = %{spans: spans, span_stack: stack}, update, override?) do
    new_spans = Enum.reduce(stack, spans, fn span_id, span_map ->
      Map.update!(span_map, span_id, &Spandex.Span.update(&1, update, override?))
    end)

    %{state | spans: new_spans}
  end

  defp edit_all_spans(state = %{spans: spans, init_span: init_span}, update, override?) do
    new_spans = Enum.into(spans, %{}, fn {span_id, span} ->
      {span_id, Spandex.Span.update(span, update, override?)}
    end)
    %{state | spans: new_spans, init_span: Spandex.Span.update(init_span, update, override?)}
  end

  defp pop_span(state = %{span_stack: []}), do: state
  defp pop_span(state = %{span_stack: [_|tail]}), do: %{state | span_stack: tail}

  defp end_init_span(state = %{init_span: span = %{completion_time: nil}}, time), do: %{state | init_span: %{span | completion_time: time}}
  defp end_init_span(state, _), do: state

  # # Callbacks
  def handle_cast({:start_span, name, time}, state) do
    new_state =
      state
      |> put_span(new_span(name, state, time))
      |> end_init_span(time)

    {:noreply, new_state}
  end

  def handle_cast({:end_span, time}, state) do
    {:noreply, complete_span(state, time)}
  end

  def handle_cast({:update_span, update, override?}, state) do
    {:noreply, edit_span(state, update, override?)}
  end

  def handle_cast({:update_span_branch, update, override?}, state) do
    {:noreply, edit_span_branch(state, update, override?)}
  end

  def handle_cast({:update_all_spans, update, override?}, state) do
    {:noreply, edit_all_spans(state, update, override?)}
  end

  def handle_cast({:publish, time}, state) do
    new_state = edit_all_spans(state, %{completion_time: time}, false)
    _ = do_publish(new_state)
    {:noreply, new_state}
  end
end
