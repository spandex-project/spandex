defmodule Spandex do
  @moduledoc """
  Documentation for Spandex.
  """

  def create_services() do
    unless Application.get_env(:spandex, :disabled?) do
      services = Application.get_env(:spandex, :services, [])
      application_name = Application.get_env(:spandex, :application_name)
      host = Application.get_env(:spandex, :host)
      port = Application.get_env(:spandex, :port)
      protocol = Application.get_env(:spandex, :protocol, :msgpack)
      for {service_name, type} <- services do
        Spandex.Datadog.Api.create_service(host, port, protocol, service_name, application_name, type)
      end
    end
  end
end
