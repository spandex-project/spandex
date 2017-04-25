defmodule Spandex.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    if Application.get_env(:spandex, :disabled?) do
      :ignore
    else
      Spandex.create_services()
      _ = ensure_table()
      # Define workers and child supervisors to be supervised
      children = [
        # Starts a worker by calling: Spandex.Worker.start_link(arg1, arg2, arg3)
        # worker(Spandex.Worker, [arg1, arg2, arg3]),
      ]

      # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
      # for other strategies and supported options
      opts = [strategy: :one_for_one, name: Spandex.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end

  defp ensure_table() do
    :ets.new(:spandex_trace, [:set, :public, :named_table])
  rescue
    _exception -> :ok
  end
end
