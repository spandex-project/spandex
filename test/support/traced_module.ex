defmodule Spandex.Test.TracedModule do
  use Spandex.TraceDecorator
  require Spandex

  defmodule TestError do
    defexception [:message]
  end

  # Traces

  @decorate trace()
  def trace_one_thing() do
    do_one_thing()
  end

  @decorate trace()
  def trace_one_error() do
    raise TestError, message: "trace_one_error"
  end

  @decorate trace()
  def error_two_deep() do
    error_one_deep()
  end

  @decorate trace()
  def two_fail_one_succeeds() do
    try do
      _ = error_one_deep()
    rescue
      _ -> nil
    end
    _ = do_one_thing()
    _ = error_one_deep()
  end

  # Spans

  @decorate span()
  def error_one_deep() do
    raise TestError, message: "error_one_deep"
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