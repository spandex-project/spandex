defmodule Spandex.Plug.StartTrace do
  @behaviour Plug
  def init(config_override), do: config_override
  def call(conn, opts) do
    conn
    |> Plug.Conn.assign(:trace, Spandex.Trace.start(opts))
  end
end
