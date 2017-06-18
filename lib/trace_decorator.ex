defmodule Spandex.TraceDecorator do
  @moduledoc """

  defmodule Foo do
    use Spandex.TraceDecorator

    @decorate traced()
    def bar(a) do
      a * 2
    end

    @decorate traced(service: "ecto", type: "sql")
    def databaz(a) do
      a * 3
    end
  end
  """
  use Decorator.Define, [span: 0, span: 1, trace: 0]

  def trace(body, context) do
    quote do
      if Confex.get(:spandex, :disabled?) do
        unquote(body)
      else
        adapter = Confex.get(:spandex, :adapter)

        name = "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ = adapter.start_trace(name)
        return_value = unquote(body)
        _ = adapter.finish_trace()
        return_value
      end
    end
  end

  def span(body, context) do
    quote do
      if Confex.get(:spandex, :disabled?) do
        unquote(body)
      else
        adapter = Confex.get(:spandex, :adapter)
        name = "#{unquote(context.name)}/#{unquote(context.arity)}"
        case adapter.start_span(name) do
          {:ok, span_id} ->
            _ = Logger.metadata([span_id: span_id])
          {:error, error} ->
            require Logger
            _ = Logger.warn("Failed to create span with error: #{error}")
        end

        try do
          return_value = unquote(body)
          _ = adapter.finish_span()
          return_value
        rescue
          exception ->
            stacktrace = System.stacktrace()
            _ = adapter.span_error(exception)
            _ = adapter.finish_span()

            reraise(exception, stacktrace)
        end
      end
    end
  end

  def span(attributes, body, context) do
    quote do
      adapter = Confex.get(:spandex, :adapter)

      if Confex.get(:spandex, :disabled?) do
        unquote(body)
      else
        attributes = unquote(attributes)
        name = attributes[:name] || "#{unquote(context.name)}/#{unquote(context.arity)}"
        case adapter.start_span(name) do
          {:ok, span_id} ->
            _ = Logger.metadata([span_id: span_id])
          {:error, error} ->
            require Logger
            _ = Logger.warn("Failed to create span with error: #{error}")
        end

        try do
          return_value = unquote(body)
          _ = adapter.finish_span()
          return_value
        rescue
          exception ->
            stacktrace = System.stacktrace()
            _ = adapter.span_error(exception)
            _ = adapter.finish_span()

            reraise(exception, stacktrace)
        end
      end
    end
  end
end
