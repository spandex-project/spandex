defmodule Spandex.Datadog.Api do
  require Logger

  def create_service(host, port, protocol, service_name, application_name, type) do
    data = %{
      service_name => %{
        app: application_name,
        app_type: type
      }
    }

    {body, content_type} = encode(protocol, data)
    HTTPoison.put(
      "#{host}:#{port}/v0.3/services",
      body,
      [{"Content-Type", content_type}]
    )
  end

  def create_trace(spans, host, port, protocol) do
    if Application.get_env(:spandex, :log_traces?) do
      {body, content_type} = encode(protocol, [spans])

      _ = Logger.info(fn -> "Trace: #{inspect(body)}" end)

      response = HTTPoison.put(
        "#{host}:#{port}/v0.3/traces",
        body,
        [{"Content-Type", content_type}]
      )

      _ = Logger.info(fn -> "Trace response: #{inspect(response)}" end)

      response
    else
      {body, content_type} = encode(protocol, [spans])
      HTTPoison.put(
        "#{host}:#{port}/v0.3/traces",
        body,
        [{"Content-Type", content_type}]
      )
    end
  end

  defp encode(:json, data) do
    {Poison.encode!(data), "application/json"}
  end

  defp encode(:msgpack, data) do
    {Msgpax.pack!(data, iodata: false), "application/msgpack"}
  end
end
