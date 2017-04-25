defmodule Spandex.Plug.EndTrace do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    unless Application.get_env(:spandex, :disabled?) do
      Spandex.Trace.update_all_spans(%{status: conn.status})
      Spandex.Trace.publish()
      :ets.delete(:spandex_trace, self())
    end

    conn
  end
end
