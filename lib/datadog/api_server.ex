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
      |> Enum.map(fn trace ->
        trace
        |> Enum.map(&format/1)
        |> Enum.sort_by(&Map.get(&1, :start))
      end)
      |> encode()
      |> push(state)

    _ =
      if verbose? do
        Logger.debug(fn -> "Trace response: #{inspect(response)}" end)
      end

    :ok
  end

  @spec format(Spandex.Span.t()) :: map
  def format(span) do
    %{
      trace_id: span.trace_id,
      span_id: span.id,
      name: span.name,
      start: span.start,
      duration: (span.completion_time || Spandex.Datadog.Utils.now()) - span.start,
      parent_id: span.parent_id,
      error: error(span.error),
      resource: span.resource,
      service: span.service,
      type: span.type,
      meta: meta(span)
    }
  end

  @spec meta(Spandex.Span.t()) :: map
  defp meta(span) do
    %{}
    |> add_datadog_meta(span)
    |> add_error_data(span)
    |> add_http_data(span)
    |> add_sql_data(span)
    |> add_tags(span)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  @spec add_datadog_meta(map, Spandex.Span.t()) :: map
  defp add_datadog_meta(meta, span) do
    Map.put(meta, :env, span.env)
  end

  @spec add_error_data(map, Spandex.Span.t()) :: map
  defp add_error_data(meta, %{error: nil}), do: meta

  defp add_error_data(meta, %{error: error}) do
    meta
    |> Map.put("error.type", error.__struct__)
    |> add_error_message(error.exception)
    |> add_error_stacktrace(error.stacktrace)
  end

  @spec add_error_message(map, Exception.t() | nil) :: map
  defp add_error_message(meta, nil), do: meta

  defp add_error_message(meta, exception),
    do: Map.put(meta, "error.msg", Exception.message(exception))

  @spec add_error_stacktrace(map, list | nil) :: map
  defp add_error_stacktrace(meta, nil), do: meta

  defp add_error_stacktrace(meta, stacktrace),
    do: Map.put(meta, "error.msg", Exception.format_stacktrace(stacktrace))

  @spec add_http_data(map, Spandex.Span.t()) :: map
  defp add_http_data(meta, %{http: nil}), do: meta

  defp add_http_data(meta, %{http: http}) do
    status_code =
      if http.status_code do
        to_string(http.status_code)
      end

    meta
    |> Map.put("http.url", http.url)
    |> Map.put("http.status_code", status_code)
    |> Map.put("http.method", http.method)
  end

  @spec add_sql_data(map, Spandex.Span.t()) :: map
  defp add_sql_data(meta, %{sql_query: nil}), do: meta

  defp add_sql_data(meta, %{sql_query: sql}) do
    meta
    |> Map.put("sql.query", sql.query)
    |> Map.put("sql.rows", sql.rows)
    |> Map.put("sql.db", sql.db)
  end

  @spec add_tags(map, Spandex.Span.t()) :: map
  defp add_tags(meta, %{tags: nil}), do: meta

  defp add_tags(meta, %{tags: tags}) do
    Map.merge(meta, Enum.into(tags, %{}))
  end

  @spec error(nil | Spandex.Span.Error.t()) :: integer
  defp error(nil), do: 0
  defp error(_), do: 1

  @spec encode(data :: term) :: iodata | no_return
  defp encode(data),
    do: data |> deep_remove_nils() |> Msgpax.pack!(data)

  @spec push(body :: iodata, t) :: any
  defp push(body, %__MODULE__{http: http, host: host, port: port}),
    do: http.put("#{host}:#{port}/v0.3/traces", body, @headers)

  @spec deep_remove_nils(term) :: term
  defp deep_remove_nils(term) when is_map(term) do
    term
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> {k, deep_remove_nils(v)} end)
    |> Enum.into(%{})
  end

  defp deep_remove_nils(term) when is_list(term) do
    if Keyword.keyword?(term) do
      term
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> {k, deep_remove_nils(v)} end)
    else
      Enum.map(term, &deep_remove_nils/1)
    end
  end

  defp deep_remove_nils(term), do: term
end
