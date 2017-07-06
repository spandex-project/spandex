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
      if Spandex.disabled?() do
        unquote(body)
      else
        name = "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ =
          case Spandex.start_trace(name) do
            {:ok, trace_id} ->
              Logger.metadata([trace_id: trace_id])
            {:error, error} ->
              {:error, error}
          end
        try do
          unquote(body)
        rescue
          exception ->
            stacktrace = System.stacktrace
            _ = Spandex.span_error(exception)

            reraise(exception, stacktrace)
        after
          _ = Spandex.finish_trace
        end
      end
    end
  end

  def trace(attributes, body, context) do
    quote do
      if Spandex.disabled?() do
        unquote(body)
      else
        attributes = unquote(attributes)
        name = attributes[:name] || "#{unquote(context.name)}/#{unquote(context.arity)}"
        name = "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ =
          case Spandex.start_trace(name) do
            {:ok, trace_id} ->
              _ = Spandex.update_span(attributes)

              Logger.metadata([trace_id: trace_id])
            {:error, error} ->
              {:error, error}
          end
        try do
          unquote(body)
        rescue
          exception ->
            stacktrace = System.stacktrace
          _ = Spandex.span_error(exception)

          reraise(exception, stacktrace)
        after
          _ = Spandex.finish_trace
        end
      end
    end
  end

  def span(body, context) do
    quote do
      if Spandex.disabled?() do
        unquote(body)
      else
        name = "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ =
          case Spandex.start_span(name) do
            {:ok, span_id} ->
              Logger.metadata([span_id: span_id])
            {:error, error} ->
              {:error, error}
          end

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
      end
    end
  end

  def span(attributes, body, context) do
    quote do
      if Spandex.disabled?() do
        unquote(body)
      else
        attributes = unquote(attributes)
        name = attributes[:name] || "#{unquote(context.name)}/#{unquote(context.arity)}"
        _ =
          case Spandex.start_span(name) do
            {:ok, span_id} ->
              _ = Spandex.update_span(attributes)
              Logger.metadata([span_id: span_id])
            {:error, error} ->
              {:error, error}
          end

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
      end
    end
  end
end
