defmodule Spandex.Span do
  @moduledoc """
  A container for all span data and metadata.

  ## Special metadata

  Apart from regular trace options, `Spandex.Span` allows specifying special
  metadata often used in web transaction tracing. These are:

  * `http` - metadata relating to the HTTP request,
  * `error` - information about the error raised during processing of the span,
  * `sql_query` - information about the SQL query this span represents.

  ### Example

  ```elixir
  [
    http: [
      url: "my_website.com?foo=bar",
      status_code: "400",
      method: "GET",
      query_string: "foo=bar",
      user_agent: "Mozilla/5.0...",
      request_id: "special_id"
    ],
    error: [
      exception: ArgumentError.exception("foo"),
      stacktrace: __STACKTRACE__,
      error?: true # Used for specifying that a span is an error when there is no exception or stacktrace.
    ],
    sql_query: [
      rows: 100,
      db: "my_database",
      query: "SELECT * FROM users;"
    ],
    # Private has the same structure as the outer meta structure, but private metadata does not
    # transfer from parent span to child span.
    private: [
      ...
    ]
  ]
  ```
  """

  alias Spandex.Span

  defstruct completion_time: nil,
            env: nil,
            error: nil,
            http: nil,
            id: nil,
            name: nil,
            parent_id: nil,
            private: [],
            resource: nil,
            service: nil,
            services: [],
            sql_query: nil,
            start: nil,
            tags: [],
            trace_id: nil,
            type: nil

  @nested_opts [:error, :http, :sql_query]

  @type t :: %Span{
          completion_time: Spandex.timestamp() | nil,
          env: String.t() | nil,
          error: Keyword.t() | nil,
          http: Keyword.t() | nil,
          id: Spandex.id(),
          name: String.t(),
          parent_id: Spandex.id() | nil,
          private: Keyword.t(),
          resource: atom() | String.t(),
          service: atom(),
          services: Keyword.t() | nil,
          sql_query: Keyword.t() | nil,
          start: Spandex.timestamp(),
          tags: Keyword.t() | nil,
          trace_id: Spandex.id(),
          type: atom()
        }

  @type option ::
          {:completion_time, integer()}
          | {:env, String.t()}
          | {:error, Keyword.t()}
          | {:http, Keyword.t()}
          | {:id, Spandex.id()}
          | {:name, String.t()}
          | {:parent_id, Spandex.id()}
          | {:private, Keyword.t()}
          | {:resource, atom() | String.t()}
          | {:service, atom()}
          | {:services, Keyword.t()}
          | {:sql_query, Keyword.t()}
          | {:start, Spandex.timestamp()}
          | {:tags, Keyword.t()}
          | {:trace_id, term()}
          | {:type, atom()}

  @type opts :: [option()]

  @doc """
  Creates a new span.
  """
  @spec new(Span.opts()) :: {:ok, Span.t()}
  def new(opts) do
    update(nil, opts)
  end

  @doc """
  Updates an existing span.
  """
  @spec update(Span.t() | nil, Span.opts()) :: {:ok, Span.t()}
  def update(span, opts) do
    opts_without_nils = Enum.reject(opts, fn {_key, value} -> is_nil(value) end)

    starting_opts =
      span
      |> Kernel.||(%Span{})
      |> Map.from_struct()
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> merge_retaining_nested(opts_without_nils)

    with_type =
      case {starting_opts[:type], starting_opts[:services]} do
        {nil, keyword} when is_list(keyword) ->
          Keyword.put(starting_opts, :type, keyword[starting_opts[:service]])

        _ ->
          starting_opts
      end

    new_span =
      if span do
        struct(span, with_type)
      else
        struct(Span, with_type)
      end

    {:ok, new_span}
  end

  @spec merge_retaining_nested(Keyword.t(), Keyword.t()) :: Keyword.t()
  defp merge_retaining_nested(left, right) do
    Keyword.merge(left, right, fn key, v1, v2 ->
      case key do
        k when k in @nested_opts ->
          left = struct_to_keyword(v1)
          right = struct_to_keyword(v2)

          merge_non_nils(left, right)

        :tags ->
          Keyword.merge(v1 || [], v2 || [])

        :private ->
          merge_or_choose(v1, v2)

        _ ->
          v2
      end
    end)
  end

  @spec merge_or_choose(Keyword.t() | nil, Keyword.t() | nil) :: Keyword.t() | nil
  defp merge_or_choose(left, right) do
    if left && right do
      merge_retaining_nested(left, right)
    else
      left || right
    end
  end

  @spec merge_non_nils(Keyword.t(), Keyword.t()) :: Keyword.t()
  defp merge_non_nils(left, right) do
    Keyword.merge(left, right, fn _k, v1, v2 ->
      if is_nil(v2) do
        v1
      else
        v2
      end
    end)
  end

  @spec child_of(Span.t(), String.t(), Spandex.id(), Spandex.timestamp(), Span.opts()) :: {:ok, Span.t()}
  def child_of(parent_span, name, id, start, opts) do
    child = %Span{parent_span | id: id, name: name, start: start, parent_id: parent_span.id}
    update(child, opts)
  end

  defp struct_to_keyword(%_struct{} = struct), do: struct |> Map.from_struct() |> Enum.into([])
  defp struct_to_keyword(keyword) when is_list(keyword), do: keyword
  defp struct_to_keyword(nil), do: []
end
