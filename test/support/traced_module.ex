defmodule Spandex.Test.TracedModule do
  use Spandex.TraceDecorator
  require Spandex

  @decorate trace()
  def trace_one_thing() do
    do_one_thing()
  end

  def manually_span_one_thing() do
    Spandex.span("manually_span_one_thing/0") do
      :timer.sleep(100)
    end
  end

  @decorate trace()
  def trace_one_task() do
    Spandex.Task.async("one_task", fn ->
      do_one_thing()
    end)
  end

  @decorate span()
  def do_one_thing() do
    :timer.sleep(100)
  end
end