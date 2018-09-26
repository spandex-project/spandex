if Code.ensure_loaded?(Decorator.Define) do
  defmodule Spandex.Decorators do
    @moduledoc """

    defmodule Foo do
      use Spandex.Decorators

      @decorate trace()
      def bar(a) do
        a * 2
      end

      @decorate trace(service: "ecto", type: "sql")
      def databaz(a) do
        a * 3
      end
    end
    """

    @tracer Application.get_env(:spandex, :decorators)[:tracer]
    def tracer, do: @tracer

    use Decorator.Define, span: 0, span: 1, trace: 0, trace: 1

    def trace(body, context) do
      trace([], body, context)
    end

    def trace(attributes, body, context) do
      quote do
        decorator = unquote(__MODULE__)
        attributes = unquote(attributes)
        tracer = attributes[:tracer] || decorator.tracer()

        attributes = Keyword.delete(attributes, :tracer)

        name =
          decorator.span_name(
            attributes,
            unquote(context.module),
            unquote(context.name),
            unquote(context.arity)
          )

        _ = tracer.start_trace(name, attributes)

        try do
          unquote(body)
        rescue
          exception ->
            stacktrace = System.stacktrace()
            _ = tracer.span_error(exception, stacktrace)

            reraise(exception, stacktrace)
        after
          _ = tracer.finish_trace()
        end
      end
    end

    def span(body, context) do
      span([], body, context)
    end

    def span(attributes, body, context) do
      quote do
        decorator = unquote(__MODULE__)
        attributes = unquote(attributes)
        tracer = attributes[:tracer] || decorator.tracer()

        attributes = Keyword.delete(attributes, :tracer)

        name =
          decorator.span_name(
            attributes,
            unquote(context.module),
            unquote(context.name),
            unquote(context.arity)
          )

        _ = tracer.start_span(name, attributes)

        try do
          unquote(body)
        rescue
          exception ->
            stacktrace = System.stacktrace()
            _ = tracer.span_error(exception, stacktrace)

            reraise(exception, stacktrace)
        after
          _ = tracer.finish_span()
        end
      end
    end

    def span_name(attributes, context_module, context_name, context_arity) do
      attributes[:name] || "#{context_module}.#{context_name}/#{context_arity}"
    end
  end
end
