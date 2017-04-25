defmodule Spandex.Span do
  defstruct [
    :id, :trace_id, :parent_id, :name, :resource,
    :service, :env, :start, :completion_time, :error,
    :error_message, :stacktrace, :type, :error_type,
    :url, :status, :method, :user, :sql_rows, :sql_db, :sql_query,
    meta: %{}
  ]

  @updateable_keys [
    :name, :resource, :service, :env, :start, :completion_time, :error,
    :error_message, :stacktrace, :error_type, :start, :status, :url, :method,
    :user
  ]

  def begin(span, time) do
    %{span | start: time || now()}
  end

  def update(span, updates, override? \\ true) do
    Enum.reduce(@updateable_keys, span, fn key, span ->
      if Map.has_key?(updates, key) do
        put_update(span, key, updates[key], override?)
      else
        span
      end
    end)
    |> merge_meta(updates[:meta] || %{})
  end

  defp merge_meta(span = %{meta: meta}, new_meta) do
    %{span | meta: Map.merge(meta, new_meta)}
  end

  def child_of(parent = %{id: parent_id}, name, id) do
    %{parent | id: id, name: name, parent_id: parent_id}
  end

  def now(), do: DateTime.utc_now |> DateTime.to_unix(:nanoseconds)

  def duration(left, right) do
    left - right
  end

  defp put_update(span, key, value, _override? = true) do
    Map.put(span, key, value)
  end
  defp put_update(span, key, value, _override?) do
    if is_nil(Map.get(span, key)) do
      Map.put(span, key, value)
    else
      span
    end
  end

  def to_json(span) do
    %{
      trace_id: span.trace_id,
      span_id: span.id,
      name: span.name,
      resource: span.resource,
      service: span.service,
      type: span.type,
      start: span.start,
      duration: duration(span.completion_time || now(), span.start || now()),
      parent_id: span.parent_id,
      error: span.error,
    }
    |> add_meta(span)
    |> add_error_data(span)
    |> add_http_data(span)
    |> add_sql_data(span)
  end

  defp add_meta(json, %{env: env, user: user, meta: meta}) do
    json
    |> Map.put(:meta, %{})
    |> put_in([:meta, :env], env)
    |> put_in([:meta, :user], user)
    |> Map.update!(:meta, fn current_meta -> Map.merge(current_meta, meta) end)
  end

  defp add_http_data(json, %{url: url, status: status, method: method}) do
    json
    |> put_in([:meta, "http.url"], url)
    |> put_in([:meta, "http.status_code"], to_string(status))
    |> put_in([:meta, "http.method"], method)
  end

  defp add_sql_data(json, span) do
    json
    |> add_if_not_nil([:meta, "sql.query"], span.sql_query)
    |> add_if_not_nil([:meta, "sql.rows"], span.sql_rows)
    |> add_if_not_nil([:meta, "sql.db"], span.sql_db)
  end

  defp add_error_data(json, %{error: 1, error_message: error_message, stacktrace: stacktrace, error_type: error_type}) do
    json
    |> put_in([:meta, "error.msg"], error_message)
    |> put_in([:meta, "error.stack"], stacktrace)
    |> put_in([:meta, "error.type"], error_type)
  end

  defp add_error_data(json, _), do: json

  defp add_if_not_nil(map, _path, nil), do: map
  defp add_if_not_nil(map, path, value), do: put_in(map, path, value)
end
