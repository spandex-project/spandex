defmodule Spandex.Span do
  defstruct [
    :id, :trace_id, :parent_id, :name, :resource,
    :service, :env, :start, :completion_time, :error,
    :error_message, :stacktrace, :type, :error_type,
    :url, :status, :method, :user
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
      meta: %{
        env: span.env,
        user: span.user
      }
    }
    |> add_error_data(span)
    |> add_http_data(span)
  end

  defp add_http_data(json, %{url: url, status: status, method: method}) do
    json
    |> put_in([:meta, "http.url"], url)
    |> put_in([:meta, "http.status"], to_string(status))
    |> put_in([:meta, "http.method"], method)
  end

  defp add_error_data(json, %{error: 1, error_message: error_message, stacktrace: stacktrace, error_type: error_type}) do
    json
    |> put_in([:meta, "error.msg"], error_message)
    |> put_in([:meta, "error.stack"], stacktrace)
    |> put_in([:meta, "error.type"], error_type)
  end

  defp add_error_data(json, _), do: json
end
