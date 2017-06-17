defmodule Spandex do
  use Application
  require Logger

  def start(_type, _args) do
    adapter = Confex.get(:spandex, :adapter)

    _ =
      if adapter do
        adapter.startup()
      else
        Logger.warn("No adapter configured for Spandex. Please configure one or disable spandex")
      end

    opts = [strategy: :one_for_one, name: Spandex.Supervisor]
    Supervisor.start_link([], opts)
  end
end