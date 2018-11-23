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

  test "child spans do not inherit metadata" do
    Tracer.trace "trace_name" do
      Tracer.update_span(sql_query: [query: "SELECT ..", db: "some_db", rows: "42"])
      Tracer.span("inner_span") do
        :ok
      end
    end

    span = Util.find_span("inner_span")

    assert(span.http == nil)
  end

  describe "metadata merging" do
    test "nested metadata is merged together" do
      Tracer.trace "trace_name" do
        Tracer.update_span(sql_query: [query: "SELECT .."])
        Tracer.update_span(sql_query: [db: "some_db"])
        Tracer.update_span(sql_query: [rows: "42"])
      end

      span = Util.find_span("trace_name")

      assert(span.sql_query) == [query: "SELECT ..", db: "some_db", rows: "42"]
    end

    test "tags are merged together" do
      Tracer.trace "trace_name" do
        Tracer.update_span(tags: [foo: :bar])
        Tracer.update_span(tags: [bar: :baz])
      end

      span = Util.find_span("trace_name")

      assert(span.tags) == [foo: :bar, bar: :baz]
    end
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
