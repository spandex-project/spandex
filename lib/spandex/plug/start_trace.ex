defmodule Spandex.Plug.StartTrace do
  @behaviour Plug
  def init(config_override), do: config_override
  def call(conn, opts) do
    {:ok, trace_pid} = Spandex.Trace.start_link(opts)

    conn
    |> Plug.Conn.assign(:current_trace, trace_pid)
  end

  def publish(conn) do
    current_trace = conn.assigns[:current_trace]

    if current_trace do
      Spandex.Trace.publish(current_trace)
    end

    conn
  rescue
    exception -> {:error, exception}
  end
end
