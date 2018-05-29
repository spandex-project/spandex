defmodule Spandex.Tracer do
  @moduledoc """
  A module that can be used to build your own tracer.

  Example:

  ```
  defmodule MyApp.Tracer do
    use Spandex.Tracer, otp_app: :my_app
  end
  ```
  """
  @type tagged_tuple :: {:ok, term} | {:error, term}
  @type span_name() :: String.t()
  @type opts :: Keyword.t()
  @type attributes :: map

  @callback configure(opts) :: :ok
  @callback start_trace(span_name, attributes, opts) :: tagged_tuple
  @callback start_span(span_name, attributes, opts) :: tagged_tuple
  @callback update_span(attributes, opts) :: tagged_tuple
  @callback update_top_span(attributes, opts) :: tagged_tuple
  @callback finish_trace(opts) :: tagged_tuple
  @callback finish_span(opts) :: tagged_tuple
  @callback span_error(error :: Exception.t(), opts) :: tagged_tuple
  @callback continue_trace(span_name, trace_id :: term, span_id :: term, opts) :: tagged_tuple
  @callback continue_trace_from_span(span_name, span :: term, opts) :: tagged_tuple
  @callback current_trace_id(opts) :: tagged_tuple
  @callback current_span_id(opts) :: tagged_tuple
  @callback current_span(opts) :: tagged_tuple
  @callback distributed_context(Plug.Conn.t(), opts) :: tagged_tuple
  @macrocallback span(span_name, attributes, opts, do: Macro.t()) :: Macro.t()
  @macrocallback trace(span_name, attributes, opts, do: Macro.t()) :: Macro.t()

  @tracer_opts Optimal.schema(
                 opts: [
                   adapter: :atom,
                   service: :atom,
                   disabled?: :boolean,
                   env: :string,
                   services: {:keyword, :atom},
                   sender: :atom
                 ],
                 required: [:adapter, :service],
                 defaults: [
                   disabled?: false,
                   env: "unknown",
                   services: [],
                   sender: Spandex.Datadog.ApiServer
                 ],
                 describe: [
                   adapter: "The third party adapter to use.",
                   service:
                     "The default service name to use for spans declared without a service.",
                   disabled?: "Allows for wholesale disabling a tracer.",
                   env:
                     "A name used to identify the environment name, e.g `prod` or `development`",
                   services:
                     "A mapping of service name to the default span types. For instance datadog knows about `:db`, `:cache` and `:web`",
                   sender:
                     "Will be deprecated soon, but this is a module that defines a `send_spans/1` function."
                 ]
               )

  @doc """
  A schema for the opts that a tracer accepts.

  #{Optimal.Doc.document(@tracer_opts)}

  All tracer functions that take opts use this schema.
  """
  def tracer_opts(), do: @tracer_opts

  defmacro __using__(opts) do
    quote do
      @otp_app unquote(opts)[:otp_app] || raise("Must provide `otp_app` to `use Spandex.Tracer`")

      @behaviour Spandex.Tracer

      alias Spandex.Tracer

      @doc """
      Use to create and configure a tracer.
      """
      @spec configure(Tracer.opts()) :: :ok
      def configure(opts) do
        config = config(opts, @otp_app)
        Application.put_env(@otp_app, __MODULE__, config)
      end

      defmacro trace(name, attrs \\ [], opts \\ [], do: body) do
        quote do
          attrs = Enum.into(unquote(attrs), %{})

          name = unquote(name)
          _ = unquote(__MODULE__).start_trace(name, attrs)
          span_id = unquote(__MODULE__).current_span_id()
          _ = Logger.metadata(span_id: span_id)

          try do
            unquote(body)
          rescue
            exception ->
              stacktrace = System.stacktrace()
              _ = unquote(__MODULE__).span_error(exception)
              reraise exception, stacktrace
          after
            unquote(__MODULE__).finish_trace()
          end
        end
      end

      defmacro span(name, attrs \\ [], opts \\ [], do: body) do
        quote do
          attrs = Enum.into(unquote(attrs), %{})

          name = unquote(name)
          _ = unquote(__MODULE__).start_span(name, attrs)
          span_id = unquote(__MODULE__).current_span_id()
          _ = Logger.metadata(span_id: span_id)

          try do
            unquote(body)
          rescue
            exception ->
              stacktrace = System.stacktrace()
              _ = unquote(__MODULE__).span_error(exception)
              reraise exception, stacktrace
          after
            unquote(__MODULE__).finish_span()
          end
        end
      end

      @spec start_trace(Tracer.span_name(), Tracer.attributes(), Tracer.opts()) ::
              Tracer.tagged_tuple()
      def start_trace(name, attributes \\ %{}, opts \\ []) do
        Spandex.start_trace(name, attributes, config(opts, @otp_app))
      end

      @spec start_span(Tracer.span_name(), Tracer.attributes(), Tracer.opts()) ::
              Tracer.tagged_tuple()
      def start_span(name, attributes \\ %{}, opts \\ []) do
        Spandex.start_span(name, attributes, config(opts, @otp_app))
      end

      @spec update_span(Tracer.attributes(), Tracer.opts()) :: Tracer.tagged_tuple()
      def update_span(attributes \\ %{}, opts \\ []) do
        Spandex.update_span(attributes, config(opts, @otp_app))
      end

      @spec update_top_span(Tracer.attributes(), Tracer.opts()) :: Tracer.tagged_tuple()
      def update_top_span(attributes \\ %{}, opts \\ []) do
        Spandex.update_top_span(attributes, config(opts, @otp_app))
      end

      @spec finish_trace(Tracer.opts()) :: Tracer.tagged_tuple()
      def finish_trace(opts \\ []) do
        opts
        |> config(@otp_app)
        |> Spandex.finish_trace()
      end

      @spec finish_span(Tracer.opts()) :: Tracer.tagged_tuple()
      def finish_span(opts \\ []) do
        opts
        |> config(@otp_app)
        |> Spandex.finish_span()
      end

      @spec span_error(error :: Exception.t(), Tracer.opts()) :: Tracer.tagged_tuple()
      def span_error(error, opts \\ []) do
        Spandex.span_error(error, config(opts, @otp_app))
      end

      @spec continue_trace(Tracer.span_name(), trace_id :: term, span_id :: term, Tracer.opts()) ::
              Tracer.tagged_tuple()
      def continue_trace(span_name, trace_id, span_id, opts \\ []) do
        Spandex.continue_trace(span_name, trace_id, span_id, config(opts, @otp_app))
      end

      @spec continue_trace_from_span(Tracer.span_name(), span :: term, Tracer.opts()) ::
              Tracer.tagged_tuple()
      def continue_trace_from_span(span_name, span, opts \\ []) do
        Spandex.continue_trace_from_span(span_name, span, config(opts, @otp_app))
      end

      @spec current_trace_id(Tracer.opts()) :: Tracer.tagged_tuple()
      def current_trace_id(opts \\ []) do
        Spandex.current_trace_id(config(opts, @otp_app))
      end

      @spec current_span_id(Tracer.opts()) :: Tracer.tagged_tuple()
      def current_span_id(opts \\ []) do
        Spandex.current_span_id(config(opts, @otp_app))
      end

      @spec current_span(Tracer.opts()) :: Tracer.tagged_tuple()
      def current_span(opts \\ []) do
        Spandex.current_span(config(opts, @otp_app))
      end

      @spec distributed_context(conn :: Plug.Conn.t(), Tracer.opts()) :: Tracer.tagged_tuple()
      def distributed_context(conn, opts \\ []) do
        Spandex.distributed_context(conn, config(opts, @otp_app))
      end

      def config(opts, otp_app) do
        otp_app
        |> Application.get_env(__MODULE__)
        |> Kernel.||([])
        |> Keyword.merge(opts || [])
        |> Optimal.validate!(Spandex.Tracer.tracer_opts())
      end
    end
  end
end
