defmodule Spandex.Plug.StartTrace do
  @behaviour Plug

  @spec init(Keyword.t) :: Keyword.t
  def init(config_override), do: config_override

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, opts) do
    unless Application.get_env(:spandex, :disabled?) do
      ignored_methods = Application.get_env(:spandex, :ignored_methods) || []
      unless conn.method in ignored_methods do
        case Spandex.Trace.start(opts) do
          {:ok, pid} ->
            :ets.insert(:spandex_trace, {self(), pid})
          _ -> :error
        end
      end
    end

    conn
  end
end
