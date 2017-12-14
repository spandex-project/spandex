defmodule Spandex.Datadog.ApiServerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Spandex.Datadog.ApiServer

  defmodule TestOkApiServer do
    def broadcast("test_channel", "trace", %{spans: spans}),
      do: send self(), {:received_spans, spans}

    def put(url, body, headers) do
      send(self(), {:put_datadog_spans, body |> Msgpax.unpack!() |> hd(), url, headers})
      {:ok, %HTTPoison.Response{status_code: 200}}
    end
  end

  defmodule TestErrorApiServer do
    def put(url, body, headers) do
      send(self(), {:put_datadog_spans, body |> Msgpax.unpack!() |> hd(), url, headers})
      {:error, %HTTPoison.Error{id: :foo, reason: :bar}}
    end
  end

  setup_all do
    {
      :ok,
      [
        spans: [%{"foo" => "bar"}, %{"baz" => "maz"}],
        url: "localhost:8126/v0.3/traces",
        state: %ApiServer{host: "localhost", port: "8126", http: TestOkApiServer, verbose: false, waiting_traces: [], batch_size: 1},
      ]
    }
  end

  describe "ApiServer.init/1" do
    test "correctly builds state with defaults" do
      {:ok, config} = ApiServer.init([])
      assert config ==
        %ApiServer{
          host: nil,
          port: nil,
          endpoint: nil,
          channel: nil,
          verbose: false,
          http: HTTPoison,
          asynchronous_send?: true,
          waiting_traces: [],
          sync_threshold: 20,
          batch_size: 10,
          agent_pid: config.agent_pid
        }
    end

    test "correctly builds state from confex" do
      dd_conf =
        :spandex
        |> Confex.get_env(:datadog)
        |> Keyword.put(:log_traces?, true)
        |> Keyword.put(:name, "foo")
        |> Keyword.put(:endpoint, TestBroadcast)
        |> Keyword.put(:channel, "test_channel")
        |> Keyword.put(:http, TestOkApiServer)
        |> Keyword.put(:asynchronous_send?, false)
        |> Keyword.put(:batch_size, 50)
        |> Keyword.put(:sync_threshold, 100)

      {:ok, config} = ApiServer.init(dd_conf)

      assert config ==
        %ApiServer{
          host: "datadog",
          port: 8126,
          endpoint: TestBroadcast,
          channel: "test_channel",
          verbose: true,
          http: TestOkApiServer,
          asynchronous_send?: false,
          agent_pid: config.agent_pid,
          batch_size: 50,
          sync_threshold: 100,
          waiting_traces: []
        }
    end
  end

  describe "ApiServer.handle_call/3 - :send_spans" do
    test "correctly sends spans to specified endpoint", %{spans: spans, state: state, url: url} do
      state = Map.put state, :verbose, true

      [processing, received_spans, response] =
        capture_log(fn -> {:reply, :ok, _} = ApiServer.handle_call({:send_spans, spans}, self(), state) end)
        |> String.split("\n")
        |> Enum.reject(fn(s) -> s == "" end)

      assert processing =~ ~r/Sending 1 traces, 2 spans/
      assert received_spans =~ ~r/Trace: \[\[\%\{\"foo\" => \"bar\"\}, %\{\"baz\" => \"maz\"\}\]\]/
      assert response =~ ~r/Trace response: {:ok, %HTTPoison.Response{body: nil, headers: \[\], request_url: nil, status_code: 200}}/
      assert_received {:put_datadog_spans, ^spans, ^url, _}
    end

    test "doesn't log anything when verbose: false", %{spans: spans, state: state, url: url} do
      log = capture_log fn ->
        {:reply, :ok, _} = ApiServer.handle_call({:send_spans, spans}, self(), state)
      end

      assert log == ""
      assert_received {:put_datadog_spans, ^spans, ^url, _}
    end

    test "doesn't care about the response result", %{spans: spans, state: state, url: url} do
      state =
        state
        |> Map.put(:verbose, true)
        |> Map.put(:http, TestErrorApiServer)

      [processing, received_spans, response] =
        capture_log(fn -> {:reply, :ok, _} = ApiServer.handle_call({:send_spans, spans}, self(), state) end)
        |> String.split("\n")
        |> Enum.reject(fn(s) -> s == "" end)

      assert processing =~ ~r/Sending 1 traces, 2 spans/
      assert received_spans =~ ~r/Trace: \[\[\%\{\"foo\" => \"bar\"\}, %\{\"baz\" => \"maz\"\}\]\]/
      assert response =~ ~r/Trace response: {:error, %HTTPoison.Error{id: :foo, reason: :bar}}/
      assert_received {:put_datadog_spans, ^spans, ^url, _}
    end

    test "broadcasts events if endpoint and channel are given", %{spans: spans, state: state} do
      state =
        state
        |> Map.put(:endpoint, TestOkApiServer)
        |> Map.put(:channel, "test_channel")

      {:reply, :ok, _} = ApiServer.handle_call({:send_spans, spans}, self(), state)

      assert_received {:received_spans, ^spans}
    end
  end
end
