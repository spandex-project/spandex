defmodule Spandex.Datadog.Api do
  @moduledoc """
  Provides functions for communicating with a datadog service using the apm api.

  This adapter uses msgpack of json for performance reasons, which is the preference
  of the datadog APM api as well. See the api documentation for more information:
  https://docs.datadoghq.com/tracing-api/
  """
  require Logger

  @doc """
  Creates a service in datadog.
  """
  @spec create_service(String.t, String.t, String.t) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
  def create_service(service_name, application_name, type) do
    data = %{
      service_name => %{
        app: application_name,
        app_type: type
      }
    }
    config = Confex.get_map(:spandex, :datadog)
    host = config[:host]
    port = config[:port]

    {body, content_type} = encode(data)
    HTTPoison.put(
      "#{host}:#{port}/v0.3/services",
      body,
      [{"Content-Type", content_type}]
    )
  end

  @doc """
  Creates a trace in datadog API, which in reality is just a list of spans
  """
  @spec create_trace([map]) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
  def create_trace(spans) do
    config = Confex.get_map(:spandex, :datadog)
    host = config[:host]
    port = config[:port]

    if Confex.get(:spandex, :log_traces?) do
      {body, content_type} = encode([spans])

      _ = Logger.info(fn -> "Trace: #{inspect([spans])}" end)

      response = HTTPoison.put(
        "#{host}:#{port}/v0.3/traces",
        body,
        [{"Content-Type", content_type}]
      )

      _ = Logger.info(fn -> "Trace response: #{inspect(response)}" end)

      response
    else
      {body, content_type} = encode([spans])
      HTTPoison.put(
        "#{host}:#{port}/v0.3/traces",
        body,
        [{"Content-Type", content_type}]
      )
    end
  end

  defp encode(data) do
    {Msgpax.pack!(data, iodata: false), "application/msgpack"}
  end
end
