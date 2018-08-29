defmodule Spandex.TestSender do
  @moduledoc """
  Simply sends the data that would have been sent to the service to self() as a message
  so that the test can assert on payloads that would have been sent to the service
  """
  def send_trace(trace, _opts \\ []) do
    send(self(), {:sent_trace, trace})
  end
end
