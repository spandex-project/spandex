defmodule Spandex.Test.SpanTest do
  use ExUnit.Case, async: true

  alias Spandex.Test.Util
  require Spandex.Test.Support.Tracer
  alias Spandex.Test.Support.Tracer

  test "updating a span does not override the service unintentionally" do
    Tracer.trace "trace_name", service: :special_service do
      Tracer.update_span(sql_query: [query: "SELECT ..", db: "some_db", rows: "42"])
    end

    span = Util.find_span("trace_name")

    assert(span.service == :special_service)
  end

  test "updating a span does not override a manually set completion_time" do
    completion = Spandex.TestAdapter.now() + :timer.minutes(10)

    Tracer.trace "trace_name" do
      Tracer.start_span("span_name")

      Tracer.update_span(completion_time: completion)

      Tracer.finish_span()

      Tracer.update_span(completion_time: completion)
    end

    span1 = Util.find_span("span_name")
    span2 = Util.find_span("trace_name")

    assert(span1.completion_time == completion)
    assert(span2.completion_time == completion)
  end
end
