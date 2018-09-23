defmodule Spandex.Test.Support.Decorated do
  @moduledoc """
  Simple module to test span and trace decorators (`Spandex.TraceDecorator`)
  """

  use Spandex.TraceDecorator
  alias Spandex.Test.Support.Tracer

  @decorate trace(name: "decorated_trace")
  def test_trace, do: :trace

  @decorate trace()
  def test_nameless_trace, do: :nameless_trace

  @decorate span(name: "decorated_span")
  def test_span, do: :span

  @decorate span()
  def test_nameless_span, do: :nameless_span
end
