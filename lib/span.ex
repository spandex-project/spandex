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
    :resource,
    :service,
    :sql_query,
    :start,
    :tags,
    :trace_id,
    :type
  ]

  @nested_opt_structs %{
    http: %Spandex.Span.Http{},
    sql_query: %Spandex.Span.SqlQuery{},
    error: %Spandex.Span.Error{}
  }

  @nested_opts Map.keys(@nested_opt_structs)

  @type timestamp :: term

  @type t :: %__MODULE__{
          completion_time: timestamp,
          env: String.t(),
          error: Spandex.Span.Error.t() | nil,
          id: term,
          name: String.t(),
          parent_id: term,
          resource: String.t(),
          service: atom,
          http: Spandex.Span.Http.t() | nil,
          sql_query: Spandex.Span.SqlQuery.t() | nil,
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
                 http: [:keyword, {:struct, Spandex.Span.Http}],
                 error: [:keyword, {:struct, Spandex.Span.Error}],
                 completion_time: :any,
                 env: :string,
                 parent_id: :any,
                 resource: [:atom, :string],
                 service: :atom,
                 services: :keyword,
                 sql_query: [:keyword, {:struct, Spandex.Span.SqlQuery}],
                 start: :any,
                 type: :atom,
                 tags: :keyword
               ],
               defaults: [
                 tags: [],
                 services: []
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
  """
  def update(span, opts, schema \\ Map.put(@span_opts, :required, [])) do
    opts_without_nils = Enum.reject(opts, fn {_key, value} -> is_nil(value) end)

    starting_opts =
      span
      |> Map.take(schema.opts)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Keyword.merge(opts_without_nils, fn key, v1, v2 ->
        case key do
          k when k in @nested_opts ->
            left = struct_to_keyword(v1)
            right = struct_to_keyword(v2)

            Keyword.merge(left, right)

          :tags ->
            Keyword.merge(v1 || [], v2 || [])

          _ ->
            v2
        end
      end)

    with_type =
      case {starting_opts[:type], starting_opts[:services]} do
        {nil, keyword} when is_list(keyword) ->
          Keyword.put(starting_opts, :type, keyword[starting_opts[:service]])

        _ ->
          starting_opts
      end

    validate_and_merge(span, with_type, schema)
  end

  @spec validate_and_merge(t(), Keyword.t(), Optimal.schema()) :: t() | {:error, term}
  defp validate_and_merge(span, opts, schema) do
    case Optimal.validate(opts, schema) do
      {:ok, opts} ->
        non_composite_opts = Keyword.drop(opts, @nested_opts)

        span = struct(span, non_composite_opts)

        opts
        |> Keyword.take(@nested_opts)
        |> Enum.reduce(span, fn {key, opts}, span ->
          struct = Map.get(span, key) || @nested_opt_structs[key]

          value = do_merge(struct, opts)

          Map.put(span, key, value)
        end)

      {:error, errors} ->
        {:error, errors}
    end
  end

  @spec do_merge(struct, struct | Keyword.t()) :: struct
  defp do_merge(struct, keyword_or_opts) do
    struct_name = struct.__struct__

    case keyword_or_opts do
      %^struct_name{} -> Map.merge(struct, keyword_or_opts)
      keyword -> struct(struct, keyword)
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
