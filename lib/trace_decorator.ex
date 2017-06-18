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
        name = "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ = Spandex.start_trace(name)
        return_value = unquote(body)
        _ = Spandex.finish_trace()
        return_value
      end
    end
  end

  def span(body, context) do
    quote do
      if Confex.get(:spandex, :disabled?) do
        unquote(body)
      else
        name = "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ =
          case Spandex.start_span(name) do
            {:ok, span_id} ->
              Logger.metadata([span_id: span_id])
            {:error, error} ->
              require Logger
              Logger.warn("Failed to create span with error: #{error}")
          end

        try do
          return_value = unquote(body)
          _ = Spandex.finish_span()
          return_value
        rescue
          exception ->
            stacktrace = System.stacktrace()
            _ = Spandex.span_error(exception)
            _ = Spandex.finish_span()

            reraise(exception, stacktrace)
        end
      end
    end
  end

  def span(attributes, body, context) do
    quote do
      require Logger
      if Confex.get(:spandex, :disabled?) do
        unquote(body)
      else
        attributes = unquote(attributes)
        name = attributes[:name] || "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ =
          case Spandex.start_span(name) do
            {:ok, span_id} ->
              Logger.metadata([span_id: span_id])
            {:error, error} ->
              Logger.warn("Failed to create span with error: #{error}")
          end

        try do
          return_value = unquote(body)
          _ = Spandex.finish_span()
          return_value
        rescue
          exception ->
            stacktrace = System.stacktrace()
            _ = Spandex.span_error(exception)
            _ = Spandex.finish_span()

            reraise(exception, stacktrace)
        end
      end
    end
  end
end
