defmodule Spandex.Test.Datadog.AdapterTest do
  use ExUnit.Case, async: true
  alias Spandex.Test.TracedModule
  alias Spandex.Test.Util

  test "a complete trace sends spans" do
    TracedModule.trace_one_thing()

    assert(Util.sent_spans())
  end

  test "a complete trace sends a top level span" do
    TracedModule.trace_one_thing()

    assert(Util.find_span("trace_one_thing/0") != nil)
  end

  test "a complete trace sends the internal spans as well" do
    TracedModule.trace_one_thing()

    assert(Util.find_span("do_one_thing/0") != nil)
  end

  test "the parent_id for a child span is correct" do
    TracedModule.trace_one_thing()

    assert(Util.find_span("trace_one_thing/0").span_id == Util.find_span("do_one_thing/0").parent_id)
  end
end