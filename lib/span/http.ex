defmodule Spandex.Span.Http do
  @moduledoc "Contains http related metadata."
  defstruct [:url, :status_code, :method, :query_string, :user_agent, :request_id]

  @type t :: %__MODULE__{
          url: String.t() | nil,
          status_code: non_neg_integer() | nil,
          method: String.t() | nil,
          query_string: String.t() | nil,
          user_agent: String.t() | nil,
          request_id: term | nil
        }
end
