if Code.ensure_loaded?(Decorator.Define) do
  defmodule Spandex.Decorators do
    @moduledoc """

    Span function decorators take an optional argument which is the attributes to update the span with. One of those attributes can be the `:tracer` in case you want to override the default tracer (e.g., in case you want to use multiple tracers).

    IMPORTANT If you define multiple clauses for a function, you'll have to decorate all of the ones you want to span.

    Note: Decorators don't magically do everything. It often makes a lot of sense to use `Tracer.update_span` from within your function to add details that are only available inside that same function.

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
      name =
        __MODULE__.span_name(
          attributes,
          context.module,
          context.name,
          context.arity
        )

      quote do
        attributes = unquote(attributes)
        tracer = attributes[:tracer] || unquote(__MODULE__).tracer()
        attributes = Keyword.delete(attributes, :tracer)

        _ = tracer.start_trace(unquote(name), attributes)

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
      name =
        __MODULE__.span_name(
          attributes,
          context.module,
          context.name,
          context.arity
        )

      quote do
        attributes = unquote(attributes)
        tracer = attributes[:tracer] || unquote(__MODULE__).tracer()
        attributes = Keyword.delete(attributes, :tracer)

        _ = tracer.start_span(unquote(name), attributes)

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
