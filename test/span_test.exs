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

  test "finishing a span does not override the completion time" do
    completion_time = :os.system_time(:nano_seconds)
    Tracer.start_trace("my_trace")
    Tracer.update_span(service: :my_app, type: :web, completion_time: completion_time)
    Tracer.finish_span()
    Tracer.finish_trace()

    span = Util.find_span("my_trace")
    assert(span.completion_time == completion_time)
  end

  test "unfinished spans should have a completion time after trace finishes" do
    Tracer.start_trace("my_trace")
    Tracer.update_span(service: :my_app, type: :web)
    Tracer.finish_trace()
    span = Util.find_span("my_trace")

    assert(span.completion_time != nil)
  end
end
