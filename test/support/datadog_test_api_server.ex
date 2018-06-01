defmodule Spandex.Test.DatadogTestApiServer do
  @moduledoc """
  Simply sends the data that would have been sent to datadog to self() as a message
  so that the test can assert on payloads that would have been sent to datadog
  """
  def send_spans(spans) do
    formatted = Enum.map(spans, &Spandex.Datadog.ApiServer.format/1)

    send(self(), {:sent_datadog_spans, formatted})
  end
end
