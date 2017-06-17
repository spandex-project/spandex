defmodule Spandex.Test.TracedModule do
  use Spandex.TraceDecorator

  @decorate trace()
  def trace_one_thing() do
    do_one_thing()
  end

  @decorate span()
  def do_one_thing() do
    :timer.sleep(100)
  end
end