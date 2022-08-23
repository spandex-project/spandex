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

  test "spans are updated with the opts passed into `finish_trace`" do
    Tracer.start_trace("my_trace")
    Tracer.update_span(service: :my_app, type: :web)
    Tracer.finish_trace(service: :your_app, type: :db)

    span = Util.find_span("my_trace")

    assert(span.service == :your_app)
    assert(span.type == :db)
  end

  test "spans are updated with the opts passed into `finish_span`" do
    Tracer.start_trace("my_trace")
    Tracer.start_span("my_span")
    Tracer.finish_span(service: :your_app)
    Tracer.finish_trace()

    span = Util.find_span("my_span")

    assert(span.service == :your_app)
  end

  test "trace names must be strings" do
    assert_raise FunctionClauseError,
                 "no function clause matching in Spandex.start_trace/2",
                 fn ->
                   Tracer.trace name: "trace_name", service: :special_service do
                     :noop
                   end
                 end
  end

  test "trace names can be interpolated at runtime" do
    Tracer.trace Enum.join(["trace", "_", "name"]), service: :special_service do
      :noop
    end

    assert Util.find_span("trace_name")
  end
end
