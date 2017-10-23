defmodule Spandex.Application do
  @moduledoc """
  Spandex supervisor.
  """

  use Application

  require Logger

  @doc """
  If DD Api Adapter is set to ApiServer we add it to supervisor children as worker.
  """
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    adapter = Confex.get_env(:spandex, :adapter)
    enabled = not Spandex.disabled?()

    if is_nil(adapter) and enabled do
      Logger.error("No adapter configured for Spandex. Please configure one or disable spandex")
    end

    dd_conf = Confex.get_env(:spandex, :datadog)

    children =
      case Keyword.get(dd_conf, :api_adapter, Spandex.Datadog.ApiServer) do
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
