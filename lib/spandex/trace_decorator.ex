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
  use Decorator.Define, [traced: 0, traced: 1]

  def traced(body, context) do
    if Confex.get(:spandex, :compile_away_spans?) do
      quote do
        unquote(body)
      end
    else
      quote do
        if Confex.get(:spandex, :disabled?) do
          unquote(body)
        else
          name = "#{unquote(context.name)}/#{unquote(context.arity)}"
          _ = Spandex.Trace.start_span(name)

          if Confex.get(:spandex, :logger_metadata?) do
            span_id = Spandex.Trace.current_span_id()
            Logger.metadata([span_id: span_id])
          end

          try do
            return_value = unquote(body)
            _ = Spandex.Trace.end_span()
            return_value
          rescue
            exception ->
              _ = Spandex.Trace.span_error(exception)
            raise exception
          end
        end
      end
    end
  end

  def traced(attributes, body, context) do
    if Confex.get(:spandex, :compile_away_spans?) do
      quote do
        unquote(body)
      end
    else
      quote do
        if Confex.get(:spandex, :disabled?) do
          unquote(body)
        else
          attributes = unquote(attributes)
          name = attributes[:name] || "#{unquote(context.name)}/#{unquote(context.arity)}"
          _ = Spandex.Trace.start_span(name)
          if Confex.get(:spandex, :logger_metadata?) do
            span_id = Spandex.Trace.current_span_id()
            Logger.metadata([span_id: span_id])
          end

          _ = Spandex.Trace.update_span(attributes |> Enum.into(%{}))

          try do
            return_value = unquote(body)
            _ = Spandex.Trace.end_span()
            return_value
          rescue
            exception ->
              _ = Spandex.Trace.span_error(exception)
            raise exception
          end
        end
      end
    end
  end
end
