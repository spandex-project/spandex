defmodule Spandex.Datadog.ApiServer do
  @moduledoc """
  Implements worker for sending spans to datadog as GenServer in order to send traces async.
  """

  use GenServer

  require Logger

  defstruct [
    :asynchronous_send?,
    :http,
    :url,
    :host,
    :port,
    :endpoint,
    :channel,
    :verbose,
    :waiting_traces,
    :batch_size,
    :sync_threshold,
    :agent_pid,
    :max_interval,
    :interval_ref,
  ]

  @type t :: %__MODULE__{}

  @headers [{"Content-Type", "application/msgpack"}]

  @doc """
  Starts genserver with given arguments.
  """
  @spec start_link(args :: Keyword.t()) :: GenServer.on_start()
  def start_link(args),
    do: GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))

  @doc """
  Builds proper state for server with some defaults.
  """
  @spec init(args :: Keyword.t()) :: {:ok, t}
  def init(args) do
    state = %__MODULE__{
      host: Keyword.get(args, :host),
      port: Keyword.get(args, :port),
      endpoint: Keyword.get(args, :endpoint),
      channel: Keyword.get(args, :channel),
      verbose: Keyword.get(args, :log_traces?, false),
      http: Keyword.get(args, :http, HTTPoison),
      asynchronous_send?: Keyword.get(args, :asynchronous_send?, true),
      waiting_traces: [],
      batch_size: Keyword.get(args, :batch_size, 10),
      sync_threshold: Keyword.get(args, :sync_threshold, 20),
      agent_pid:
        Keyword.get_lazy(args, :agent_pid, fn ->
          {:ok, pid} = Agent.start_link(fn -> 0 end, name: :spandex_currently_send_count)
          pid
        end),
      max_interval: Keyword.get(args, :max_interval, 10)
    }

    state = send_interval_msg(state)

    {:ok, state}
  end

  @doc """
  Send spans asynchronously to DataDog.
  """
  @spec send_spans(spans :: list(map), Keyword.t()) :: :ok
  def send_spans(spans, opts \\ []) do
    GenServer.call(__MODULE__, {:send_spans, spans}, Keyword.get(opts, :timeout, 30_000))
  end

  @doc false
  @spec handle_call({:send_spans, spans :: list(map)}, pid, state :: t) :: {:noreply, t}
  def handle_call(
        {:send_spans, spans},
        _from,
        %__MODULE__{waiting_traces: waiting_traces, batch_size: batch_size, verbose: verbose} =
          state
      )
      when length(waiting_traces) + 1 < batch_size do
    if verbose do
      Logger.info(fn -> "Adding trace to stack with #{Enum.count(spans)} spans" end)
    end

    {:reply, :ok, %{state | waiting_traces: [spans | waiting_traces]}}
  end

  def handle_call({:send_spans, spans}, _from, %__MODULE__{waiting_traces: waiting_traces} = state) do
    all_traces = [spans | waiting_traces]

    state = do_send_spans(%{state | waiting_traces: all_traces})

    {:reply, :ok, state}
  end

  def handle_call(:send_spans, _from, state) do
    state = do_send_spans(state)

    {:reply, :ok, state}
  end

  def handle_info(:interval, %__MODULE__{waiting_traces: []} = state) do
    state = send_interval_msg(state)

    {:noreply, state}
  end

  def handle_info(:interval, %__MODULE__{verbose: verbose} = state) do
    if verbose, do: Logger.info(fn -> "Max interval reached, sending spans now." end)

    server = self()
    Task.start(fn -> GenServer.call(server, :send_spans) end)

    {:noreply, state}
  end

  defp do_send_spans(
      %__MODULE__{
        verbose: verbose,
        asynchronous_send?: asynchronous?,
        waiting_traces: waiting_traces,
        sync_threshold: sync_threshold,
        agent_pid: agent_pid
      } = state
    ) do

    if verbose do
      trace_count = Enum.count(waiting_traces)

      span_count =
        waiting_traces
        |> Enum.map(&Enum.count/1)
        |> Enum.sum()

      Logger.info(fn -> "Sending #{trace_count} traces, #{span_count} spans." end)

      Logger.debug(fn -> "Trace: #{inspect([Enum.concat(waiting_traces)])}" end)
    end

    if asynchronous? do
      below_sync_threshold? =
        Agent.get_and_update(agent_pid, fn count ->
          if count < sync_threshold do
            {true, count + 1}
          else
            {false, count}
          end
        end)

      if below_sync_threshold? do
        Task.start(fn ->
          try do
            send_and_log(waiting_traces, state)
          after
            Agent.update(agent_pid, fn count -> count - 1 end)
          end
        end)
      else
        # We get benefits from running in a separate process (like better GC)
        # So we async/await here to mimic the behavour above but still apply backpressure
        task = Task.async(fn -> send_and_log(waiting_traces, state) end)
        Task.await(task)
      end
    else
      send_and_log(waiting_traces, state)
    end

    state = send_interval_msg(state)
    %{state | waiting_traces: []}
  end

  @spec send_and_log(traces :: list(list(map)), any) :: :ok
  def send_and_log(traces, %{verbose: verbose} = state) do
    response =
      traces
      |> encode()
      |> push(state)

    if verbose do
      Logger.debug(fn -> "Trace response: #{inspect(response)}" end)
    end

    broadcast(traces, state)

    :ok
  end

  @spec broadcast(traces :: list(list(map)), t) :: any
  defp broadcast(_spans, %__MODULE__{endpoint: e, channel: c}) when is_nil(e) or is_nil(c),
    do: :noop

  defp broadcast(traces, %__MODULE__{endpoint: endpoint, channel: channel}),
    do: endpoint.broadcast(channel, "trace", %{spans: Enum.concat(traces)})

  @spec encode(data :: term) :: iodata | no_return
  defp encode(data),
    do: Msgpax.pack!(data)

  @spec push(body :: iodata, t) :: any
  defp push(body, %__MODULE__{http: http, host: host, port: port}),
    do: http.put("#{host}:#{port}/v0.3/traces", body, @headers)

  defp send_interval_msg(%__MODULE__{max_interval: :infinity} = state), do: state
  defp send_interval_msg(%__MODULE__{max_interval: interval, interval_ref: interval_ref} = state) do
    if is_reference(interval_ref), do: Process.cancel_timer(interval_ref)

    timer_ref = Process.send_after(self(), :interval, trunc(interval * 1000))

    %{state | interval_ref: timer_ref}
  end
end
