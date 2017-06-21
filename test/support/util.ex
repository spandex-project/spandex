defmodule Spandex.Test.Util do
  def can_fail(func) do
    func.()
  rescue
    _exception -> nil
  end

  def find_span(name) when is_bitstring(name) do
    find_span(fn span -> span.name == name end)
  end

  def find_span(fun) when is_function(fun) do
    Enum.find(sent_spans(), fun)
  end

  def find_span(name, index) when is_bitstring(name) do
    find_span(fn span -> span.name == name end, index)
  end

  def find_span(fun, index) when is_function(fun) do
    sent_spans()
    |> Enum.filter(fun)
    |> Enum.at(index)
  end

  def sent_spans() do
    receive do
      {:sent_datadog_spans, spans} ->
        send(self(), {:sent_datadog_spans, spans})
        spans
      after 5000 ->
        raise "No datadog spans sent"
    end
  end
end