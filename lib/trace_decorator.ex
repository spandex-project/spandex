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
  use Decorator.Define, span: 0, span: 1, trace: 0, trace: 1

  def trace(body, context) do
    trace([], body, context)
  end

  def trace(attributes, body, context) do
    quote do
      if Spandex.disabled?() do
        unquote(body)
      else
        attributes = Enum.into(unquote(attributes), %{})
        level = Map.get(attributes, :level, Spandex.default_level())

        if Spandex.should_span?(level) do
          name =
            Spandex.TraceDecorator.span_name(
              attributes,
              unquote(context.name),
              unquote(context.arity)
            )

          _ = Spandex.start_trace(name, attributes)

          try do
            unquote(body)
          rescue
            exception ->
              stacktrace = System.stacktrace()
              _ = Spandex.span_error(exception)

              reraise(exception, stacktrace)
          after
            _ = Spandex.finish_trace()
          end
        else
          unquote(body)
        end
      end
    end
  end

  def span(body, context) do
    span([], body, context)
  end

  def span(attributes, body, context) do
    quote do
      if Spandex.disabled?() do
        unquote(body)
      else
        attributes = Enum.into(unquote(attributes), %{})
        level = Map.get(attributes, :level, Spandex.default_level())

        if Spandex.should_span?(level) do
          name =
            Spandex.TraceDecorator.span_name(
              attributes,
              unquote(context.name),
              unquote(context.arity)
            )

          _ = Spandex.start_span(name, attributes)

          try do
            unquote(body)
          rescue
            exception ->
              stacktrace = System.stacktrace()
              _ = Spandex.span_error(exception)

              reraise(exception, stacktrace)
          after
            _ = Spandex.finish_span()
          end
        else
          unquote(body)
        end
      end
    end
  end

  def span_name(attributes, context_name, context_arity) do
    attributes[:name] || "#{context_name}/#{context_arity}"
  end
end
