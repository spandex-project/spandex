defmodule Spandex.Test.TracedModule do
  @moduledoc false
  require Spandex

  require Spandex.Test.Support.Tracer
  alias Spandex.Test.Support.Tracer

  defmodule TestError do
    defexception [:message]
  end

  # Traces

  def trace_one_thing() do
    Tracer.trace "trace_one_thing/0" do
      do_one_thing()
    end
  end

  def trace_with_special_name() do
    Tracer.trace "special_name", service: :special_service do
      do_one_special_name_thing()
    end
  end

  def trace_one_error() do
    Tracer.trace "trace_one_error/0" do
      raise TestError, message: "trace_one_error"
    end
  end

  def error_two_deep() do
    Tracer.trace "error_two_deep/0" do
      error_one_deep()
    end
  end

  def two_fail_one_succeeds() do
    Tracer.trace "two_fail_one_succeeds/0" do
      try do
        _ = error_one_deep()
      rescue
        _ -> nil
      end

      _ = do_one_thing()
      _ = error_one_deep()
    end
  end

  # Spans

  def error_one_deep() do
    Tracer.span "error_one_deep/0" do
      raise TestError, message: "error_one_deep"
    end
  end

  def manually_span_one_thing() do
    Tracer.span "manually_span_one_thing/0" do
      :timer.sleep(100)
    end
  end

  def do_one_thing() do
    Tracer.span "do_one_thing/0" do
      :timer.sleep(100)
    end
  end

  def do_one_special_name_thing() do
    Tracer.span "special_name_span", service: :special_span_service do
      :timer.sleep(100)
    end
  end
end
