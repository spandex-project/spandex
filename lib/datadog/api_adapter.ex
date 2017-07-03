defmodule Spandex.Datadog.ApiAdapter do
  @moduledoc """
  Exists to easily swap out the network implementation.
  """
  require Logger

  def send_services(data) do
    config = Confex.get_map(:spandex, :datadog)
    host = config[:host]
    port = config[:port]

    if Confex.get(:spandex, :log_traces?) do
      body = encode(data)

      _ = Logger.info(fn -> "Service: #{inspect(data)}" end)

      response =
        HTTPoison.put(
          "#{host}:#{port}/v0.3/services",
          body,
          [{"Content-Type", "application/msgpack"}]
        )

      _ = Logger.info(fn -> "Service Response: #{inspect(response)}" end)
      response
    else
      body = encode(data)
      HTTPoison.put(
        "#{host}:#{port}/v0.3/services",
        body,
        [{"Content-Type", "application/msgpack"}]
      )
    end

  end

  def send_spans(spans) do
    config = Confex.get_map(:spandex, :datadog)
    host = config[:host]
    port = config[:port]

    _ =
      if config[:endpoint] && config[:channel] do
        config[:endpoint].broadcast(config[:channel], "trace", %{spans: spans})
      end

    if Confex.get(:spandex, :log_traces?) do
      body = encode([spans])

      _ = Logger.info(fn -> "Trace: #{inspect([spans])}" end)

      response = HTTPoison.put(
        "#{host}:#{port}/v0.3/traces",
        body,
        [{"Content-Type", "application/msgpack"}]
      )

      _ = Logger.info(fn -> "Trace response: #{inspect(response)}" end)

      response
    else
      body = encode([spans])
      HTTPoison.put(
        "#{host}:#{port}/v0.3/traces",
        body,
        [{"Content-Type", "application/msgpack"}]
      )
    end
  end

  defp encode(data) do
    Msgpax.pack!(data, iodata: false)
  end
end
