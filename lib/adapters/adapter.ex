defmodule Spandex.Adapters.Adapter do
  @moduledoc """
  Describes the callback for a tracing adapter. Can be used to provide different
  implementations of reporting/aggregating spans while still using the spandex
  internal implementation.
  """
  @callback start_trace(String.t) :: {:ok, term} | {:error, term}
  @callback start_span(String.t) :: {:ok, term} | {:error, term}
  @callback update_span(map) :: :ok | {:error, term}
  @callback finish_span() :: :ok | {:error, term}
  @callback finish_trace() :: :ok | {:error, term}
  @callback span_error(Exception.t) :: :ok | {:error, term}
  @callback current_trace_id() :: term | nil | {:error, term}
  @callback current_span_id() :: term | nil | {:error, term}
  @callback current_span() :: term | nil
  @callback continue_trace(String.t, term, term) :: {:ok, term} | {:error, term}
  @callback continue_trace_from_span(String.t, map) :: {:ok, term} | {:error, term}
  @callback update_top_span(map) :: :ok | {:error, term}
  @callback update_all_spans(map) :: :ok | {}
  @callback distributed_context(Plug.Conn.t) :: {:ok, term} | {:error, term}
end
