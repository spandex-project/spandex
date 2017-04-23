defmodule Spandex.Span do
  defstruct [
    :id, :trace_id, :parent_id, :name, :resource,
    :service, :env, :start, :completion_time, :error,
    :error_message, :stacktrace, :type
  ]

  @updateable_keys [:name, :resource, :service, :env, :start, :completion_time, :error, :error_message, :stacktrace, :type]

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
        env: span.env
      }
    } |> add_error_data(span)
  end

  defp add_error_data(json, %{error: 1, error_message: error_message, stacktrace: stacktrace}) do
    json
    |> put_in([:meta, :error_message], error_message)
    |> put_in([:meta, :stacktrace], stacktrace)
  end

  defp add_error_data(json, _), do: json
end
