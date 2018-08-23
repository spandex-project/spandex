defmodule Spandex.Adapter do
  @moduledoc """
  The callbacks required to implement the Spandex.Adapter behaviour.
  """

  @callback distributed_context(Plug.Conn.t(), Keyword.t()) :: {:ok, term} | {:error, term}
  @callback trace_id() :: Spandex.id()
  @callback span_id() :: Spandex.id()
  @callback now() :: Spandex.timestamp()
  @callback default_sender() :: module()
end
