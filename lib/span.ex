defmodule Spandex.Span do
  @moduledoc """
  A container for all span data and metadata.
  """
  defstruct [
    :completion_time,
    :env,
    :error,
    :http,
    :id,
    :name,
    :parent_id,
    :private,
    :resource,
    :service,
    :sql_query,
    :start,
    :tags,
    :trace_id,
    :type
  ]

  @nested_opts [:error, :http, :sql_query]

  @type timestamp :: term

  @type t :: %__MODULE__{
          completion_time: timestamp,
          env: String.t(),
          error: Keyword.t() | nil,
          id: term,
          name: String.t(),
          parent_id: term,
          private: Keyword.t(),
          resource: String.t(),
          service: atom,
          http: Keyword.t() | nil,
          sql_query: Keyword.t() | nil,
          start: timestamp,
          trace_id: term,
          tags: Keyword.t() | nil,
          type: atom
        }

  @span_opts Optimal.schema(
               opts: [
                 id: :any,
                 trace_id: :any,
                 name: :string,
                 http: :keyword,
                 error: :keyword,
                 completion_time: :any,
                 env: :string,
                 parent_id: :any,
                 private: :keyword,
                 resource: [:atom, :string],
                 service: :atom,
                 services: :keyword,
                 sql_query: :keyword,
                 start: :any,
                 type: :atom,
                 tags: :keyword
               ],
               defaults: [
                 tags: [],
                 services: [],
                 private: []
               ],
               required: [
                 :id,
                 :trace_id,
                 :name,
                 :env,
                 :service,
                 :start
               ],
               extra_keys?: true
             )

  def span_opts(), do: @span_opts

  @doc """
  Create a new span.

  #{Optimal.Doc.document(@span_opts)}
  """
  def new(opts) do
    update(%__MODULE__{}, opts, @span_opts)
  end

  @doc """
  Update an existing span.

  #{Optimal.Doc.document(Map.put(@span_opts, :required, []))}

  ## Special Meta

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
      stacktrace: System.stacktrace(),
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
  def update(span, opts, schema \\ Map.put(@span_opts, :required, [])) do
    opts_without_nils = Enum.reject(opts, fn {_key, value} -> is_nil(value) end)

    starting_opts =
      span
      |> Map.take(schema.opts)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> merge_retaining_nested(opts_without_nils)

    with_type =
      case {starting_opts[:type], starting_opts[:services]} do
        {nil, keyword} when is_list(keyword) ->
          Keyword.put(starting_opts, :type, keyword[starting_opts[:service]])

        _ ->
          starting_opts
      end

    validate_and_merge(span, with_type, schema)
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
          if v1 && v2 do
            merge_retaining_nested(v1, v2)
          else
            v1 || v2
          end

        _ ->
          v2
      end
    end)
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

  @spec validate_and_merge(t(), Keyword.t(), Optimal.schema()) :: t() | {:error, term}
  defp validate_and_merge(span, opts, schema) do
    case Optimal.validate(opts, schema) do
      {:ok, opts} ->
        struct(span, opts)

      {:error, errors} ->
        {:error, errors}
    end
  end

  def child_of(%{id: parent_id} = parent, name, id, start, opts) do
    child = %{parent | id: id, name: name, start: start, parent_id: parent_id}

    update(child, opts)
  end

  defp struct_to_keyword(%_struct{} = struct), do: struct |> Map.from_struct() |> Enum.into([])
  defp struct_to_keyword(keyword) when is_list(keyword), do: keyword
  defp struct_to_keyword(nil), do: []
end
