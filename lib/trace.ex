defmodule Spandex.Trace do
  @moduledoc """
  A representation of an ongoing trace.

  * `baggage`: Key-value metadata about the overall trace (propagated across distributed service)
  * `id`: The trace ID, which consistently refers to this trace across distributed services
  * `priority`: The trace sampling priority for this trace (propagated across distributed services)
  * `spans`: The set of completed spans for this trace from this process
  * `stack`: The stack of active parent spans
  """
  defstruct baggage: [],
            id: nil,
            priority: nil,
            spans: [],
            stack: []

  @typedoc @moduledoc
  @type t :: %__MODULE__{
          baggage: Keyword.t(),
          id: Spandex.id(),
          priority: integer(),
          spans: [Spandex.Span.t()],
          stack: [Spandex.Span.t()]
        }
end
