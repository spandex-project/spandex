defmodule Spandex.Test.Datadog.AdapterTest do
  use ExUnit.Case, async: true
  alias Test.Support.TracedModule

  test "creates services on startup" do
    TracedModule.trace_one_thing()
  end
end