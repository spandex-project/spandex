defmodule Spandex.Test.Util do
  def find_span(name) when is_bitstring(name) do
    Enum.find(sent_spans(), fn span -> span.name == name end)
  end

  def find_span(fun) when is_function(fun) do
    Enum.find(sent_spans(), fun)
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