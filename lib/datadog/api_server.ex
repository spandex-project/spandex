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
    :verbose?,
    :waiting_traces,
    :batch_size,
    :sync_threshold,
    :agent_pid
  ]

  @type t :: %__MODULE__{}

  @headers [{"Content-Type", "application/msgpack"}]

  @start_link_opts Optimal.schema(
                     opts: [
                       host: :string,
                       port: [:integer, :string],
                       verbose?: :boolean,
                       http: :atom,
                       batch_size: :integer,
                       sync_threshold: :integer,
                       api_adapter: :atom
                     ],
                     defaults: [
                       host: "localhost",
                       port: 8126,
                       verbose?: false,
                       batch_size: 10,
                       sync_threshold: 20,
                       api_adapter: Spandex.Datadog.ApiServer
                     ],
                     required: [:http],
                     describe: [
                       verbose?:
                         "Only to be used for debugging: All finished traces will be logged",
                       host: "The host the agent can be reached at",
                       port: "The port to use when sending traces to the agent",
                       batch_size: "The number of traces that should be sent in a single batch",
                       sync_threshold:
                         "The maximum number of processes that may be sending traces at any one time. This adds backpressure",
                       http:
                         "The HTTP module to use for sending spans to the agent. Currently only HTTPoison has been tested",
                       api_adapter: "Which api adapter to use. Currently only used for testing"
                     ]
                   )

  @doc """
  Starts genserver with given options.

  #{Optimal.Doc.document(@start_link_opts)}
  """
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    opts = Optimal.validate!(opts, @start_link_opts)

    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Builds server state.
  """
  @spec init(opts :: Keyword.t()) :: {:ok, t}
  def init(opts) do
    {:ok, agent_pid} = Agent.start_link(fn -> 0 end, name: :spandex_currently_send_count)

    state = %__MODULE__{
      asynchronous_send?: true,
      host: opts[:host],
      port: opts[:port],
      verbose?: opts[:verbose?],
      http: opts[:http],
      waiting_traces: [],
      batch_size: opts[:batch_size],
      sync_threshold: opts[:sync_threshold],
      agent_pid: agent_pid
    }

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
  @spec handle_call({:send_spans, spans :: list(map)}, term, state :: t) :: {:reply, :ok, t}
  def handle_call(
        {:send_spans, spans},
        _from,
        %__MODULE__{waiting_traces: waiting_traces, batch_size: batch_size, verbose?: verbose?} =
          state
      )
      when length(waiting_traces) + 1 < batch_size do
    _ =
      if verbose? do
        Logger.info(fn -> "Adding trace to stack with #{Enum.count(spans)} spans" end)
      end

    {:reply, :ok, %{state | waiting_traces: [spans | waiting_traces]}}
  end

  def handle_call(
        {:send_spans, spans},
        _from,
        %__MODULE__{
          verbose?: verbose?,
          asynchronous_send?: asynchronous?,
          waiting_traces: waiting_traces,
          sync_threshold: sync_threshold,
          agent_pid: agent_pid
        } = state
      ) do
    all_traces = [spans | waiting_traces]

    _ =
      if verbose? do
        trace_count = Enum.count(all_traces)

        span_count =
          all_traces
          |> Enum.map(&Enum.count/1)
          |> Enum.sum()

        _ = Logger.info(fn -> "Sending #{trace_count} traces, #{span_count} spans." end)

        Logger.debug(fn -> "Trace: #{inspect([Enum.concat(all_traces)])}" end)
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
            send_and_log(all_traces, state)
          after
            Agent.update(agent_pid, fn count -> count - 1 end)
          end
        end)
      else
        # We get benefits from running in a separate process (like better GC)
        # So we async/await here to mimic the behavour above but still apply backpressure
        task = Task.async(fn -> send_and_log(all_traces, state) end)
        Task.await(task)
      end
    else
      send_and_log(all_traces, state)
    end

    {:reply, :ok, %{state | waiting_traces: []}}
  end

  @spec send_and_log(traces :: list(list(map)), any) :: :ok
  def send_and_log(traces, %{verbose?: verbose?} = state) do
    response =
      traces
      |> encode()
      |> push(state)

    _ =
      if verbose? do
        Logger.debug(fn -> "Trace response: #{inspect(response)}" end)
      end

    :ok
  end

  @spec encode(data :: term) :: iodata | no_return
  defp encode(data),
    do: Msgpax.pack!(data)

  @spec push(body :: iodata, t) :: any
  defp push(body, %__MODULE__{http: http, host: host, port: port}),
    do: http.put("#{host}:#{port}/v0.3/traces", body, @headers)
end
