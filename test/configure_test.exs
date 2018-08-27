defmodule Spandex.Test.ConfigureTest do
  use ExUnit.Case, async: false

  alias Spandex.Test.Util
  require Spandex.Test.Support.Tracer
  alias Spandex.Test.Support.Tracer

  test "disabled tracer should not have results" do
    original_env = Application.get_env(:spandex, Tracer)
    assert :ok = Tracer.configure(disabled?: true)

    Tracer.trace "my_trace" do
    end

    span = Util.can_fail(fn -> Util.find_span("my_trace") end)

    assert(span == nil)

    Tracer.configure(original_env)
  end
end
