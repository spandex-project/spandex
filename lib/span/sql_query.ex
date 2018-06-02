defmodule Spandex.Span.SqlQuery do
  @moduledoc "Contains sql query related metadata."
  defstruct [:rows, :db, :query]

  @type t :: %__MODULE__{
          rows: non_neg_integer() | nil,
          db: String.t() | nil,
          query: String.t() | nil
        }
end
