defmodule Spandex.Span do
  @moduledoc """
  A container for all span data and metadata.
  """

  alias Spandex.Span

  defstruct [
    :completion_time,
    :env,
    :error,
    :http,
    :id,
    :name,
    :parent_id,
    :resource,
    :service,
    :services,
    :sql_query,
    :start,
    :tags,
    :trace_id,
    :type
  ]

  @nested_opts [:error, :http, :sql_query]

  @type t :: %Span{
          completion_time: Spandex.timestamp() | nil,
          env: String.t() | nil,
          error: Keyword.t() | nil,
          http: Keyword.t() | nil,
          id: Spandex.id(),
          name: String.t(),
          parent_id: Spandex.id() | nil,
          resource: atom() | String.t(),
          service: atom(),
          services: Keyword.t() | nil,
          sql_query: Keyword.t() | nil,
          start: Spandex.timestamp(),
          tags: Keyword.t() | nil,
          trace_id: Spandex.id(),
          type: atom()
        }

  @span_opts Optimal.schema(
               opts: [
                 completion_time: :integer,
                 env: :string,
                 error: :keyword,
                 http: :keyword,
                 id: :any,
                 name: :string,
                 parent_id: :any,
                 resource: [:atom, :string],
                 service: :atom,
                 services: :keyword,
                 sql_query: :keyword,
                 start: :integer,
                 tags: :keyword,
                 trace_id: :any,
                 type: :atom
               ],
               defaults: [
                 services: [],
                 tags: []
               ],
               required: [
                 :id,
                 :name,
                 :service,
                 :start,
                 :trace_id
               ],
               extra_keys?: true
             )

  def span_opts(), do: @span_opts

  @doc """
  Create a new span.

  #{Optimal.Doc.document(@span_opts)}
  """
  @spec new(Keyword.t()) ::
          {:ok, Span.t()}
          | {:error, [Optimal.error()]}
  def new(opts) do
    update(nil, opts, @span_opts)
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
    ]
  ]
  ```
  """
  @spec update(Span.t() | nil, Keyword.t(), Optimal.Schema.t()) ::
          {:ok, Span.t()}
          | {:error, [Optimal.error()]}
  def update(span, opts, schema \\ Map.put(@span_opts, :required, [])) do
    opts_without_nils = Enum.reject(opts, fn {_key, value} -> is_nil(value) end)

    starting_opts =
      span
      |> Kernel.||(%{})
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

  @spec validate_and_merge(Span.t() | nil, Keyword.t(), Optimal.schema()) ::
          {:ok, Span.t()}
          | {:error, [Optimal.error()]}
  defp validate_and_merge(span, opts, schema) do
    case Optimal.validate(opts, schema) do
      {:ok, opts} ->
        new_span =
          if span do
            struct(span, opts)
          else
            struct(Span, opts)
          end

        {:ok, new_span}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @spec child_of(Span.t(), String.t(), Spandex.id(), Spandex.timestamp(), Keyword.t()) ::
          {:ok, Span.t()}
          | {:error, [Optimal.error()]}
  def child_of(parent_span, name, id, start, opts) do
    child =
      %Span{
        id: id,
        name: name,
        start: start,
        parent_id: parent_span.id,
        env: parent_span.env,
        resource: parent_span.resource,
        service: parent_span.service,
        type: parent_span.type,
        trace_id: parent_span.trace_id
      }

    update(child, opts)
  end

  defp struct_to_keyword(%_struct{} = struct), do: struct |> Map.from_struct() |> Enum.into([])
  defp struct_to_keyword(keyword) when is_list(keyword), do: keyword
  defp struct_to_keyword(nil), do: []
end
