defmodule Spandex.Datadog.ApiServer do
  @moduledoc """
  Implements worker for sending spans to datadog as GenServer in order to send traces async.
  """

  use GenServer

  require Logger

  defstruct [:http, :url, :host, :port, :endpoint, :channel, :verbose]

  @type t :: %__MODULE__{}

  @headers [{"Content-Type", "application/msgpack"}]

  @doc """
  Starts genserver with given arguments.
  """
  @spec start_link(args :: Keyword.t) :: GenServer.on_start
  def start_link(args),
    do: GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))

  @doc """
  Builds proper state for server with some defaults.
  """
  @spec init(args :: Keyword.t) :: {:ok, t}
  def init(args) do
    state = %__MODULE__{
      host:     Keyword.get(args, :host),
      port:     Keyword.get(args, :port),
      endpoint: Keyword.get(args, :endpoint),
      channel:  Keyword.get(args, :channel),
      verbose:  Keyword.get(args, :log_traces?, false),
      http:     Keyword.get(args, :http, HTTPoison),
    }

    {:ok, state}
  end

  @doc """
  Send spans asynchronously to DataDog.
  """
  @spec send_spans(spans :: list(map), any) :: :ok
  def send_spans(spans, name \\ __MODULE__) do
    GenServer.cast name, {:send_spans, spans}
  end

  @doc false
  @spec handle_cast({:send_spans, spans :: list(map)}, state :: t) :: {:noreply, t}
  def handle_cast({:send_spans, spans}, %__MODULE__{verbose: verbose} = state) do
    if verbose do
      Logger.info  fn -> "Processing trace with #{Enum.count(spans)} spans" end
      Logger.debug fn -> "Trace: #{inspect([spans])}" end
    end

    response =
      [spans]
      |> encode()
      |> push(state)

    if verbose do
      Logger.debug fn -> "Trace response: #{inspect(response)}" end
    end

    broadcast(spans, state)

    {:noreply, state}
  end

  @spec broadcast(spans :: list(map), t) :: any
  defp broadcast(_spans, %__MODULE__{endpoint: e, channel: c}) when is_nil(e) or is_nil(c),
    do: :noop
  defp broadcast(spans, %__MODULE__{endpoint: endpoint, channel: channel}),
    do: endpoint.broadcast(channel, "trace", %{spans: spans})

  @spec encode(data :: term) :: iodata | no_return
  defp encode(data),
    do: Msgpax.pack!(data, iodata: false)

  @spec push(body :: iodata, t) :: any
  defp push(body, %__MODULE__{http: http, host: host, port: port}),
    do: http.put("#{host}:#{port}/v0.3/traces", body, @headers)
end
