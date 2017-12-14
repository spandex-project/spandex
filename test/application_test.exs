defmodule Spandex.ApplicationTest do
  @moduledoc """
  Feature test from top to bottom.
  """

  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Spandex.Test.TracedModule

  def with_conf(app, key, val, fun),
    do: with_conf(app, key, val, Application.get_env(app, key), fun)

  def with_conf(app, key, new_val, old_val, fun) do
    Application.put_env app, key, new_val
    fun.()
  after
    Application.put_env app, key, old_val
  end

  defmodule TestBroadcast do
    def broadcast("test_channel", "trace", %{spans: spans}),
      do: send Spandex.ApplicationTest, {:received_spans, Enum.count(spans)}

    def put(_, body, _) do
      send Spandex.ApplicationTest, {:sent_spans_to_dd, body |> Msgpax.unpack!() |> hd() |> Enum.count()}
      {:ok, %HTTPoison.Response{body: "OK", status_code: 200}}
    end
  end

  setup_all do
    HTTPoison.start
  end

  test "correctly starts supervisor" do
    GenServer.stop Spandex.Supervisor
    Process.register self(), __MODULE__
    {:ok, pid} = Agent.start_link(fn -> 0 end, name: :spandex_currently_send_count)

    conf =
      :spandex
      |> Confex.get_env(:datadog)
      |> Keyword.merge([
        api_adapter: Spandex.Datadog.ApiServer,
        host: "localhost",
        endpoint: TestBroadcast,
        channel: "test_channel",
        http: TestBroadcast,
        asynchronous_send?: false,
        agent_pid: pid,
        batch_size: 1
      ])

    with_conf :spandex, :log_traces?, true, fn ->
      with_conf :spandex, :datadog, conf, fn ->
        {:ok, _pid} = Spandex.Application.start(:foo, :bar)

        log = capture_log fn ->
          TracedModule.trace_with_special_name()
          assert_receive {:received_spans, 2}, 1_000
          assert_receive {:sent_spans_to_dd, 2}, 1_000
        end

        [processing, spans, response] = log |> String.split("\n") |> Enum.reject(fn(s) -> s == "" end) |> Enum.take(-3)

        assert processing =~ ~r/Sending 1 traces, 2 spans/
        assert spans =~ ~r/name: "special_name"/
        assert spans =~ ~r/name: "special_name_span"/
        assert spans =~ ~r/type: :job/
        assert response =~ ~r/Trace response: {:ok, %HTTPoison.Response{body: \"OK\", headers: \[\], request_url: nil, status_code: 200}}/
      end
    end

    Spandex.Application.start(:foo, :bar)
  end
end
