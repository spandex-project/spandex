defmodule Spandex.Adapter do
  @moduledoc """
  The callbacks required to implement the Spandex.Adapter behaviour.
  """

  @callback distributed_context(Plug.Conn.t(), Keyword.t()) ::
              {:ok, Spandex.SpanContext.t()}
              | {:error, atom()}
  @callback inject_context(Spandex.headers(), Spandex.SpanContext.t(), Keyword.t()) :: Spandex.headers()
  @callback trace_id() :: Spandex.id()
  @callback span_id() :: Spandex.id()
  @callback now() :: Spandex.timestamp()
  @callback default_sender() :: module()
end
