defmodule Spandex.Span.Error do
  @moduledoc "Contains error related metadata."
  defstruct [:exception, :stacktrace]

  @type t :: %__MODULE__{
          exception: Exception.t() | nil,
          stacktrace: [] | nil
        }
end
