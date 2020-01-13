defmodule Spandex.DecoratorsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  require Logger

  alias Spandex.Test.Support.Decorated
  alias Spandex.Test.Support.OtherTracer
  alias Spandex.Test.Support.Tracer
  alias Spandex.Test.Util

  test "creates trace when decorating function with trace annotation" do
    Decorated.test_trace()

    assert Util.find_span("decorated_trace") != nil
  end

  test "creates trace named after module name, function name and arity when nameless" do
    Decorated.test_nameless_trace()

    assert Util.find_span("Spandex.Test.Support.Decorated.test_nameless_trace/0") != nil
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

    assert Util.find_span("Spandex.Test.Support.Decorated.test_nameless_span/0") != nil
  end

  test "uses another tracer when overriding it via the tracer option" do
    OtherTracer.start_trace("my_trace")
    Decorated.test_other_tracer()
    OtherTracer.finish_trace()

    assert Util.find_span("Spandex.Test.Support.Decorated.test_other_tracer/0") != nil
  end

  test "when decorating with trace, it logs span_id and trace_id" do
    log =
      capture_log(fn ->
        Decorated.test_trace()
        Logger.info("test logs")
      end)

    assert String.contains?(log, "trace_id")
    assert String.contains?(log, "span_id")
  end

  test "when decorating with span, it logs span_id and trace_id" do
    log =
      capture_log(fn ->
        Tracer.start_trace("my_trace")
        Decorated.test_span()
        Tracer.finish_trace()

        Logger.info("test logs")
      end)

    assert String.contains?(log, "trace_id")
    assert String.contains?(log, "span_id")
  end
end
