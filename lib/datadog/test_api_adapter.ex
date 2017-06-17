defmodule Spandex.Datadog.TestApiAdapter do
  @moduledoc """
  Simply sends the data that would have been sent to datadog to self() as a message
  so that the test can assert on payloads that would have been sent to datadog
  """
  def send_services(data) do
    send(self(), {:sent_datadog_services, data})
  end

  def send_spans(spans) do
    send(self(), {:sent_datadog_spans, spans})
  end
end