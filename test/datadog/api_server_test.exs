defmodule Spandex.Datadog.ApiServerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Spandex.Datadog.ApiServer

  defmodule TestOkApiServer do
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
    {:ok, agent_pid} = Agent.start_link(fn -> 0 end, name: :spandex_currently_send_count)

    {
      :ok,
      [
        spans: [%{"foo" => "bar"}, %{"baz" => "maz"}],
        url: "localhost:8126/v0.3/traces",
        state: %ApiServer{
          asynchronous_send?: false,
          host: "localhost",
          port: "8126",
          http: TestOkApiServer,
          verbose?: false,
          waiting_traces: [],
          batch_size: 1,
          agent_pid: agent_pid
        }
      ]
    }
  end

  describe "ApiServer.handle_call/3 - :send_spans" do
    test "doesn't log anything when verbose?: false", %{spans: spans, state: state, url: url} do
      log =
        capture_log(fn ->
          {:reply, :ok, _} = ApiServer.handle_call({:send_spans, spans}, self(), state)
        end)

      assert log == ""
      assert_received {:put_datadog_spans, ^spans, ^url, _}
    end

    test "doesn't care about the response result", %{spans: spans, state: state, url: url} do
      state =
        state
        |> Map.put(:verbose?, true)
        |> Map.put(:http, TestErrorApiServer)

      [processing, received_spans, response] =
        capture_log(fn ->
          {:reply, :ok, _} = ApiServer.handle_call({:send_spans, spans}, self(), state)
        end)
        |> String.split("\n")
        |> Enum.reject(fn s -> s == "" end)

      assert processing =~ ~r/Sending 1 traces, 2 spans/

      assert received_spans =~
               ~r/Trace: \[\[\%\{\"foo\" => \"bar\"\}, %\{\"baz\" => \"maz\"\}\]\]/

      assert response =~ ~r/Trace response: {:error, %HTTPoison.Error{id: :foo, reason: :bar}}/
      assert_received {:put_datadog_spans, ^spans, ^url, _}
    end
  end
end
