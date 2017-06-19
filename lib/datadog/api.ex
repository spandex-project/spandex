defmodule Spandex.Datadog.Api do
  @moduledoc """
  Provides functions for communicating with a datadog service using the apm api.

  This adapter uses msgpack of json for performance reasons, which is the preference
  of the datadog APM api as well. See the api documentation for more information:
  https://docs.datadoghq.com/tracing-api/
  """

  @doc """
  Creates a service in datadog.
  """
  @spec create_service(String.t, String.t, String.t) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t} | :disabled
  def create_service(service_name, application_name, type) do
    if Spandex.disabled?() do
      :disabled
    else
      data = %{
        service_name => %{
          app: application_name,
          app_type: type
        }
      }
      adapter = Confex.get_map(:spandex, :datadog)[:api_adapter] || Spandex.Datadog.ApiAdapter
      adapter.send_services(data)
    end
  end

  @doc """
  Creates a trace in datadog API, which in reality is just a list of spans
  """
  @spec create_trace([map]) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t} | :disabled
  def create_trace(spans) do
    if Spandex.disabled?() do
      :disabled
    else
      adapter = Confex.get_map(:spandex, :datadog)[:api_adapter] || Spandex.Datadog.ApiAdapter
      adapter.send_spans(spans)
    end
  end
end
