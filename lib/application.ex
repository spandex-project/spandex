defmodule Spandex.Application do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    adapter = Confex.get_env(:spandex, :adapter)

    unless adapter do
      Logger.warn("No adapter configured for Spandex. Please configure one or disable spandex")
    end

    children = [
    ]

    opts = [strategy: :one_for_one, name: Spandex.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
