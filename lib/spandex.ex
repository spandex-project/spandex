defmodule Spandex do
  @moduledoc """
  Documentation for Spandex.
  """

  def create_services() do
    unless Confex.get(:spandex, :disabled?) do
      services = Confex.get(:spandex, :services, [])
      application_name = Confex.get(:spandex, :application_name)
      host = Confex.get(:spandex, :host)
      port = Confex.get(:spandex, :port)
      protocol = Confex.get(:spandex, :protocol, :msgpack)
      for {service_name, type} <- services do
        Spandex.Datadog.Api.create_service(host, port, protocol, service_name, application_name, type)
      end
    end
  end
end
