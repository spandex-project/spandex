defmodule Spandex.SpanContext do
  @moduledoc """
  From the [OpenTracing specification]:
  > Each SpanContext encapsulates the following state:
  > * Any OpenTracing-implementation-dependent state (for example, trace and span ids) needed to refer to a distinct Span across a process boundary
  > * Baggage Items, which are just key:value pairs that cross process boundaries

  [OpenTracing specification]: https://github.com/opentracing/specification/blob/master/specification.md
  """

  @typedoc @moduledoc
  @type t :: %__MODULE__{
          trace_id: Spandex.id(),
          parent_id: Spandex.id(),
          priority: integer() | nil,
          baggage: Keyword.t()
        }

  defstruct trace_id: nil,
            parent_id: nil,
            priority: nil,
            baggage: []
end
