defmodule Spandex.Adapters.Adapter do
  @moduledoc """
  The callbacks required to implement an adapter.
  """

  @callback distributed_context(Plug.Conn.t(), Keyword.t()) :: {:ok, term} | {:error, term}
  @callback trace_id() :: term
  @callback span_id() :: term
  @callback now() :: term
  @callback default_sender() :: module
end
