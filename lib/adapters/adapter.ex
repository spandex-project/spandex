defmodule Spandex.Adapters.Adapter do
  @moduledoc """
  Describes the callback for a tracing adapter. Can be used to provide different
  implementations of reporting/aggregating spans while still using the spandex
  internal implementation.
  """
  @callback start_trace(String.t(), Keyword.t()) :: {:ok, term} | {:error, term}
  @callback start_span(String.t(), Keyword.t()) :: {:ok, term} | {:error, term}
  @callback update_span(Keyword.t()) :: :ok | {:error, term}
  @callback finish_span(Keyword.t()) :: :ok | {:error, term}
  @callback finish_trace(Keyword.t()) :: :ok | {:error, term}
  @callback span_error(Exception.t(), Keyword.t()) :: :ok | {:error, term}
  @callback current_trace_id(Keyword.t()) :: term | nil | {:error, term}
  @callback current_span_id(Keyword.t()) :: term | nil | {:error, term}
  @callback current_span(Keyword.t()) :: term | nil
  @callback continue_trace(String.t(), term, term, Keyword.t()) :: {:ok, term} | {:error, term}
  @callback continue_trace_from_span(String.t(), map, Keyword.t()) :: {:ok, term} | {:error, term}
  @callback update_top_span(Keyword.t()) :: :ok | {:error, term}
  @callback update_all_spans(Keyword.t()) :: :ok | {}
  @callback distributed_context(Plug.Conn.t(), Keyword.t()) :: {:ok, term} | {:error, term}
end
