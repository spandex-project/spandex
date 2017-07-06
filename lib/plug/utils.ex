defmodule Spandex.Plug.Utils do
  @moduledoc """
  Helper methods for accessing Spandex plug assigns.
  """

  @plug_trace_var :spandex_trace_request?

  @doc """
  Stores in conn whenever we trace request or not.
  """
  @spec trace(conn :: Plug.Conn.t, trace? :: boolean) :: Plug.Conn.t
  def trace(conn, trace?),
    do: Plug.Conn.assign(conn, @plug_trace_var, trace?)

  @doc """
  Checks conn whenever we trace request or not.
  """
  @spec trace?(conn :: Plug.Conn.t) :: boolean
  def trace?(conn),
    do: conn.assigns[@plug_trace_var] == true
end
