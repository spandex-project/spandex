defmodule Spandex.Test.Support.Decorated do
  @moduledoc """
  Simple module to test span and trace decorators (`Spandex.Decorators`)
  """

  use Spandex.Decorators
  alias Spandex.Test.Support.OtherTracer

  @decorate trace(name: "decorated_trace")
  def test_trace, do: :trace

  @decorate trace()
  def test_nameless_trace, do: :nameless_trace

  @decorate span(name: "decorated_span")
  def test_span, do: :span

  @decorate span()
  def test_nameless_span, do: :nameless_span

  @decorate span(tracer: OtherTracer)
  def test_other_tracer, do: :other_tracer
end
