defmodule Spandex.TestSender do
  @moduledoc """
  Simply sends the data that would have been sent to the service to self() as a message
  so that the test can assert on payloads that would have been sent to the service
  """
  def send_spans(spans) do
    send(self(), {:sent_spans, spans})
  end
end
