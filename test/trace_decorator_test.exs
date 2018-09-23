defmodule Spandex.TraceDecoratorTest do
  use ExUnit.Case, async: true

  alias Spandex.Test.Support.Decorated
  alias Spandex.Test.Support.Tracer
  alias Spandex.Test.Util

  test "creates trace when decorating function with trace annotation" do
    Decorated.test_trace()

    assert Util.find_span("decorated_trace") != nil
  end

  test "creates trace named after module name, function name and arity when nameless" do
    Decorated.test_nameless_trace()

    assert Util.find_span("Elixir.Spandex.Test.Support.Decorated.test_nameless_trace/0") != nil
  end

  test "creates span when decorating function with span annotation" do
    Tracer.start_trace("my_trace")
    Decorated.test_span()
    Tracer.finish_trace()

    assert Util.find_span("decorated_span") != nil
  end

  test "creates span named after module name, function name and arity when nameless" do
    Tracer.start_trace("my_trace")
    Decorated.test_nameless_span()
    Tracer.finish_trace()

    assert Util.find_span("Elixir.Spandex.Test.Support.Decorated.test_nameless_span/0") != nil
  end
end
