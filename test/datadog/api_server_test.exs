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
    trace_id = 4_743_028_846_331_200_905

    span_1 =
      Spandex.Span.new(
        id: 4_743_028_846_331_200_906,
        start: 1_527_752_052_216_478_000,
        service: :foo,
        env: "local",
        name: "foo",
        trace_id: trace_id,
        completion_time: 1_527_752_052_216_578_000
      )

    span_2 =
      Spandex.Span.new(
        id: 4_743_029_846_331_200_906,
        start: 1_527_752_052_216_578_001,
        completion_time: 1_527_752_052_316_578_001,
        service: :bar,
        env: "local",
        name: "bar",
        trace_id: trace_id
      )

    {
      :ok,
      [
        spans: [span_1, span_2],
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

      formatted = [
        %{
          "duration" => 100_000,
          "error" => 0,
          "meta" => %{"env" => "local"},
          "name" => "foo",
          "service" => "foo",
          "span_id" => 4_743_028_846_331_200_906,
          "start" => 1_527_752_052_216_478_000,
          "trace_id" => 4_743_028_846_331_200_905
        },
        %{
          "duration" => 100_000_000,
          "error" => 0,
          "meta" => %{"env" => "local"},
          "name" => "bar",
          "service" => "bar",
          "span_id" => 4_743_029_846_331_200_906,
          "start" => 1_527_752_052_216_578_001,
          "trace_id" => 4_743_028_846_331_200_905
        }
      ]

      assert_received {:put_datadog_spans, ^formatted, ^url, _}
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

      assert received_spans =~ ~r/Trace: \[\[%Spandex.Span{/

      formatted = [
        %{
          "duration" => 100_000,
          "error" => 0,
          "meta" => %{"env" => "local"},
          "name" => "foo",
          "service" => "foo",
          "span_id" => 4_743_028_846_331_200_906,
          "start" => 1_527_752_052_216_478_000,
          "trace_id" => 4_743_028_846_331_200_905
        },
        %{
          "duration" => 100_000_000,
          "error" => 0,
          "meta" => %{"env" => "local"},
          "name" => "bar",
          "service" => "bar",
          "span_id" => 4_743_029_846_331_200_906,
          "start" => 1_527_752_052_216_578_001,
          "trace_id" => 4_743_028_846_331_200_905
        }
      ]

      assert response =~ ~r/Trace response: {:error, %HTTPoison.Error{id: :foo, reason: :bar}}/
      assert_received {:put_datadog_spans, ^formatted, ^url, _}
    end
  end
end
