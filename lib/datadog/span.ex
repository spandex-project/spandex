defmodule Spandex.Datadog.Span do
  @moduledoc """
  In charge of holding the datadog span attributes, and for starting/ending
  spans. This also handles serialization via `to_map/1`, and span inheritance
  via `child_of/3`
  """

  alias __MODULE__, as: Span
  alias Spandex.Datadog.Utils

  defstruct [
    :id, :trace_id, :parent_id, :name, :resource,
    :service, :env, :start, :completion_time, :error,
    :error_message, :stacktrace, :type, :error_type,
    :url, :status, :method, :user, :sql_rows, :sql_db, :sql_query,
    meta: %{}
  ]

  @type t :: %__MODULE__{}

  @default "unknown"
  @updateable_keys [
    :name, :resource, :service, :env, :start, :completion_time, :error,
    :error_message, :stacktrace, :error_type, :start, :status, :url, :method,
    :user, :type
  ]

  @doc """
  Creates new struct with defaults from :spandex configuration.
  """
  @spec new(map :: map) :: t
  def new(map \\ %{}) do
    core = %Span{
      id:       default_if_blank(map, :id, &Utils.next_id/0),
      start:    default_if_blank(map, :start, &Utils.now/0),
      env:      default_if_blank(map, :env, &default_env/0),
      service:  default_if_blank(map, :service, &default_service/0),
      resource: default_if_blank(map, :resource, fn -> default_if_blank(map, :name, fn -> @default end) end),
    }

    core
    |> Map.put(:type, default_if_blank(map, :type, fn -> default_type(core.service) end))
    |> Map.merge(Map.drop(map, [:id, :start, :env, :service, :resource, :type]))
  end

  @doc """
  Sets completion time for given span if it's missing as unix epoch in nanoseconds.
  """
  @spec stop(span :: t) :: t
  def stop(%Span{completion_time: nil} = span),
    do: %{span | completion_time: Utils.now()}
  def stop(%Span{} = span),
    do: span

  @doc """
  Updates span with given map. Only `@updateable_keys` are allowed for updates.
  """
  @spec update(span :: t, updates :: map) :: t
  def update(%Span{} = span, updates) do
    @updateable_keys
    |> Enum.reduce(span, fn key, span ->
      if Map.has_key?(updates, key) do
        Map.put(span, key, updates[key])
      else
        span
      end
    end)
    |> merge_meta(updates[:meta] || %{})
  end

  defp merge_meta(%Span{meta: meta} = span, new_meta) do
    %{span | meta: Map.merge(meta, new_meta)}
  end

  @doc """
  Creates new span based on parent span.
  """
  @spec child_of(parent :: t, name :: term) :: t
  def child_of(%Span{id: parent_id} = parent, name) do
    %{parent | id: Utils.next_id(), start: Utils.now(), name: name, parent_id: parent_id}
  end

  defp duration(left, right) do
    left - right
  end

  defp default_if_blank(map, key, fun) do
    case Map.get(map, key) do
      nil -> fun.()
      val -> val
    end
  end

  @doc """
  Creates a final map structure suitable for datadog trace agent.
  """
  @spec to_map(span :: t) :: map
  def to_map(%Span{} = span) do
    service = span.service || default_service()
    now = Utils.now()

    %{
      trace_id: span.trace_id,
      span_id: span.id,
      name: span.name,
      start: span.start || now,
      duration: duration(span.completion_time || now, span.start || now),
      parent_id: span.parent_id,
      error: span.error || 0,
      resource: span.resource || span.name || @default,
      service: service,
      type: span.type || default_type(service)
    }
    |> add_meta(span)
    |> add_error_data(span)
    |> add_http_data(span)
    |> add_sql_data(span)
  end

  defp add_meta(json, %{env: env, user: user, meta: meta}) do
    json
    |> Map.put(:meta, %{})
    |> put_in([:meta, :env], env || default_env())
    |> add_if_not_nil([:meta, :user], user)
    |> Map.update!(:meta, fn current_meta -> Map.merge(current_meta, meta) end)
    |> filter_nils
  end

  defp add_http_data(json, %{url: url, status: status, method: method}) do
    json
    |> add_if_not_nil([:meta, "http.url"], url)
    |> add_string_if_not_nil([:meta, "http.status_code"], status)
    |> add_if_not_nil([:meta, "http.method"], method)
  end

  defp add_sql_data(json, span) do
    json
    |> add_if_not_nil([:meta, "sql.query"], span.sql_query)
    |> add_if_not_nil([:meta, "sql.rows"], span.sql_rows)
    |> add_if_not_nil([:meta, "sql.db"], span.sql_db)
  end

  defp add_error_data(json, %{error: 1, error_message: error_message, stacktrace: stacktrace, error_type: error_type}) do
    json
    |> add_if_not_nil([:meta, "error.msg"], error_message)
    |> add_if_not_nil([:meta, "error.stack"], stacktrace)
    |> add_if_not_nil([:meta, "error.type"], error_type)
  end

  defp add_error_data(json, _), do: json

  defp add_if_not_nil(map, _path, nil), do: map
  defp add_if_not_nil(map, path, value), do: put_in(map, path, value)

  defp add_string_if_not_nil(map, _path, nil), do: map
  defp add_string_if_not_nil(map, path, value), do: put_in(map, path, to_string(value))

  defp filter_nils(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{}, fn {key, value} -> {key, filter_nils(value)} end)
  end
  defp filter_nils(other), do: other

  defp default_service, do: Confex.get_env(:spandex, :service)
  defp default_env, do: Confex.get_env(:spandex, :datadog)[:env]
  defp default_type(service) do
    :spandex
    |> Confex.get_env(:datadog)
    |> Keyword.get(:services, [])
    |> Keyword.get(service, @default)
  end
end
