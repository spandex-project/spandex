defmodule Spandex do
  @moduledoc """
  Documentation for Spandex.
  """

  def create_services() do
    services = Application.get_env(:spandex, :services, [])
    application_name = Application.get_env(:spandex, :application_name)
    host = Application.get_env(:spandex, :host)
    port = Application.get_env(:spandex, :port)
    for {service_name, type} <- services do
      body = %{
        service_name => %{
          app: application_name,
          app_type: type
        }
      }

      HTTPoison.put("#{host}:#{port}/v0.3/services", Poison.encode!(body), [{"Content-Type", "application/json"}])
    end
  end
end
