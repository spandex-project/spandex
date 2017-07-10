defmodule Spandex.Application do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    adapter = Confex.get_env(:spandex, :adapter)

    unless adapter do
      Logger.warn("No adapter configured for Spandex. Please configure one or disable spandex")
    end

    dd_conf = Confex.get_env(:spandex, :datadog)

    children =
      case dd_conf[:api_adapter] do
        Spandex.Datadog.ApiServer ->
          verbose = Confex.get_env(:spandex, :log_traces?)
          args = Keyword.put(dd_conf, :log_traces?, verbose)

          [worker(Spandex.Datadog.ApiServer, [args])]
        _ ->
          []
      end

    opts = [strategy: :one_for_one, name: Spandex.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
