defmodule Spandex.Trace do
  @moduledoc """
  A representation of an ongoing trace.

  `stack` represents all parent spans, while `spans` represents
  all completed spans.

  """
  defstruct [:stack, :spans, :id, :start]

  @type t :: %__MODULE__{
          stack: [Spandex.Span.t()],
          spans: [Spandex.Span.t()],
          id: Spandex.id()
        }
end
