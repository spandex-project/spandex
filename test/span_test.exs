defmodule Spandex.Test.SpanTest do
  use ExUnit.Case, async: true

  alias Spandex.Test.Util
  require Spandex.Test.Support.Tracer
  alias Spandex.Test.Support.Tracer

  test "starting updating a span does not override the service unintentionally" do
    Tracer.trace "trace_name", service: :special_service do
      Tracer.update_span(sql_query: [query: "SELECT ..", db: "some_db", rows: "42"])
    end

    span = Util.find_span("trace_name")

    assert(span.service == :special_service)
  end
end
