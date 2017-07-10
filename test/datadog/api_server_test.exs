defmodule Spandex.Datadog.ApiServerTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  import ExUnit.CaptureLog

  alias Spandex.Datadog.ApiServer

  defmodule TestBroadcast do
    def broadcast("test_channel", "trace", %{spans: spans}),
      do: send self(), {:received_spans, spans}
  end

  setup_all do
    HTTPoison.start
    {
      :ok,
      [spans: [%{foo: :bar}, %{baz: :maz}]]
    }
  end

  describe "ApiServer.init/1" do
    test "correctly builds state with defaults" do
      assert ApiServer.init([]) == {
        :ok,
        %ApiServer{
          host: nil,
          port: nil,
          url: ":/v0.3/traces",
          endpoint: nil,
          channel: nil,
          verbose: false,
        }
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

      assert ApiServer.init(dd_conf) == {
        :ok,
        %ApiServer{
          host: "datadog",
          port: 8126,
          url: "datadog:8126/v0.3/traces",
          endpoint: TestBroadcast,
          channel: "test_channel",
          verbose: true,
        }
      }
    end
  end

  describe "ApiServer.handle_cast/2 - :send_spans" do
    test "correctly sends spans to specified endpoint", %{spans: spans} do
      use_cassette "datadog_api_server_ok" do
        state = %ApiServer{url: "localhost:8126/v0.3/traces", verbose: true}

        [processing, spans, response] =
          capture_log(fn -> {:noreply, ^state} = ApiServer.handle_cast({:send_spans, spans}, state) end)
          |> String.split("\n")
          |> Enum.reject(fn(s) -> s == "" end)

        assert processing =~ ~r/Processing trace with 2 spans/
        assert spans =~ ~r/Trace: \[\[\%\{foo: :bar\}, %\{baz: :maz\}\]\]/
        assert response =~ ~r/Trace response: {:ok, %HTTPoison.Response{body: \"OK\\n\"/
        assert response =~ ~r/status_code: 200/
      end
    end

    test "doesn't log anything when verbose: false", %{spans: spans} do
      use_cassette "datadog_api_server_ok" do
        state = %ApiServer{url: "localhost:8126/v0.3/traces", verbose: false}

        log = capture_log fn ->
          {:noreply, ^state} = ApiServer.handle_cast({:send_spans, spans}, state)
        end

        assert log == ""
      end
    end

    test "doesn't care about the response result", %{spans: spans} do
      use_cassette "datadog_api_server_error" do
        state = %ApiServer{url: "localhost:8126/v0.3/traces", verbose: true}

        [processing, spans, response] =
          capture_log(fn -> {:noreply, ^state} = ApiServer.handle_cast({:send_spans, spans}, state) end)
          |> String.split("\n")
          |> Enum.reject(fn(s) -> s == "" end)

        assert processing =~ ~r/Processing trace with 2 spans/
        assert spans =~ ~r/Trace: \[\[\%\{foo: :bar\}, %\{baz: :maz\}\]\]/
        assert response =~ ~r/Trace response: {:error, %HTTPoison.Error{id: nil, reason: \"econnrefused\"}}/
      end
    end

    test "broadcasts events if endpoint and channel are given", %{spans: spans} do
      use_cassette "datadog_api_server_ok" do
        state = %ApiServer{
          url: "localhost:8126/v0.3/traces",
          verbose: false,
          endpoint: TestBroadcast,
          channel: "test_channel",
        }

        {:noreply, ^state} = ApiServer.handle_cast({:send_spans, spans}, state)

        assert_received {:received_spans, ^spans}
      end
    end
  end
end
