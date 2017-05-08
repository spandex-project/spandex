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

  def traced(attributes, body, context = %{args: arguments}) do
    if Confex.get(:spandex, :compile_away_spans?) do
      quote do
        unquote(body)
      end
    else
      traceable_args = traceable_args(attributes, arguments)

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

            _ = attributes
              |> Enum.into(%{})
              |> Map.put_new(:meta, %{})
              |> put_in([:meta, :args], unquote(traceable_args))
              |> Map.delete(:args)
              |> Spandex.Trace.update_span()

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

  defp traceable_args(attributes, arguments) do
    attributes
    |> Keyword.get(:args, [])
    |> Enum.with_index()
    |> Enum.map(fn {filter, index} ->
      argument_value = Enum.at(arguments, index)
      list_filter = List.wrap(filter)
      cond do
        filter == false -> {index, "_"}
        filter == true -> {index, inspect(argument_value)}
        is_map(argument_value) -> {index, inspect(Map.take(argument_value, list_filter))}
        Keyword.keyword?(argument_value) -> {index, inspect(Enum.filter(argument_value, fn {key, _value} -> key in list_filter end))}
        is_list(argument_value) -> {index, inspect(Enum.map(list_filter, &Enum.at(argument_value, &1)))}
        true -> {index, inspect(argument_value)}
      end
    end)
    |> Enum.into(%{})
  rescue
    %{}
  end
end
