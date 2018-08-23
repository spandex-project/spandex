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

  alias Spandex.Trace
  alias Spandex.Span

  @type tagged_tuple(arg) :: {:ok, arg} | {:error, term}
  @type span_name() :: String.t()
  @type opts :: Keyword.t() | :disabled

  @callback configure(opts) :: :ok
  @callback start_trace(span_name, opts) :: tagged_tuple(Trace.t())
  @callback start_span(span_name, opts) :: tagged_tuple(Span.t())
  @callback update_span(opts) :: tagged_tuple(Span.t())
  @callback update_top_span(opts) :: tagged_tuple(Span.t())
  @callback finish_trace(opts) :: tagged_tuple(Trace.t())
  @callback finish_span(opts) :: tagged_tuple(Span.t())
  @callback span_error(error :: Exception.t(), stacktrace :: [term], opts) ::
              tagged_tuple(Span.t())
  @callback continue_trace(span_name, trace_id :: term, span_id :: term, opts) ::
              tagged_tuple(Trace.t())
  @callback continue_trace_from_span(span_name, span :: term, opts) :: tagged_tuple(Trace.t())
  @callback current_trace_id(opts) :: nil | Spandex.id()
  @callback current_span_id(opts) :: nil | Spandex.id()
  @callback current_span(opts) :: nil | Span.t()
  @callback distributed_context(Plug.Conn.t(), opts) :: tagged_tuple(map)
  @macrocallback span(span_name, opts, do: Macro.t()) :: Macro.t()
  @macrocallback trace(span_name, opts, do: Macro.t()) :: Macro.t()

  @tracer_opts Optimal.schema(
                 opts: [
                   adapter: :atom,
                   service: :atom,
                   disabled?: :boolean,
                   env: :string,
                   services: {:keyword, :atom},
                   strategy: :atom,
                   sender: :atom,
                   tracer: :atom
                 ],
                 required: [:adapter, :service],
                 defaults: [
                   disabled?: false,
                   env: "unknown",
                   services: [],
                   strategy: Spandex.Strategy.Pdict
                 ],
                 describe: [
                   adapter: "The third party adapter to use",
                   tracer: "Don't set manually. This option is passed automatically.",
                   sender:
                     "Once a trace is complete, it is sent using this module. Defaults to the `default_sender/0` of the selected adapter",
                   service:
                     "The default service name to use for spans declared without a service",
                   disabled?: "Allows for wholesale disabling a tracer",
                   env:
                     "A name used to identify the environment name, e.g `prod` or `development`",
                   services: "A mapping of service name to the default span types.",
                   strategy:
                     "The storage and tracing strategy. Currently only supports local process dictionary."
                 ]
               )

  @all_tracer_opts @tracer_opts
                   |> Optimal.merge(
                     Span.span_opts(),
                     annotate: "Span Creation",
                     add_required?: false
                   )
                   |> Map.put(:extra_keys?, false)

  @doc """
  A schema for the opts that a tracer accepts.

  #{Optimal.Doc.document(@all_tracer_opts)}

  All tracer functions that take opts use this schema.
  This also accepts defaults for any value that can
  be given to a span.
  """
  def tracer_opts(), do: @all_tracer_opts

  defmacro __using__(opts) do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      @otp_app unquote(opts)[:otp_app] || raise("Must provide `otp_app` to `use Spandex.Tracer`")

      @behaviour Spandex.Tracer

      @opts Spandex.Tracer.tracer_opts()

      @doc """
      Use to create and configure a tracer.
      """
      @impl Spandex.Tracer
      @spec configure(Tracer.opts()) :: :ok
      def configure(opts) do
        case config(opts, @otp_app) do
          :disabled ->
            :ok

          config ->
            Application.put_env(@otp_app, __MODULE__, config)
        end
      end

      @impl Spandex.Tracer
      defmacro trace(name, opts \\ [], do: body) do
        quote do
          opts = unquote(opts)

          name = unquote(name)
          _ = unquote(__MODULE__).start_trace(name, opts)
          span_id = unquote(__MODULE__).current_span_id()
          _ = Logger.metadata(span_id: span_id)

          try do
            unquote(body)
          rescue
            exception ->
              stacktrace = System.stacktrace()
              _ = unquote(__MODULE__).span_error(exception, stacktrace, opts)
              reraise exception, stacktrace
          after
            unquote(__MODULE__).finish_trace()
          end
        end
      end

      @impl Spandex.Tracer
      defmacro span(name, opts \\ [], do: body) do
        quote do
          opts = unquote(opts)
          name = unquote(name)
          _ = unquote(__MODULE__).start_span(name, opts)
          span_id = unquote(__MODULE__).current_span_id()
          _ = Logger.metadata(span_id: span_id)

          try do
            unquote(body)
          rescue
            exception ->
              stacktrace = System.stacktrace()
              _ = unquote(__MODULE__).span_error(exception, stacktrace, opts)
              reraise exception, stacktrace
          after
            unquote(__MODULE__).finish_span()
          end
        end
      end

      @impl Spandex.Tracer
      def start_trace(name, opts \\ []) do
        Spandex.start_trace(name, config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def start_span(name, opts \\ []) do
        Spandex.start_span(name, config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def update_span(opts) do
        Spandex.update_span(validate_update_config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def update_top_span(opts) do
        Spandex.update_top_span(validate_update_config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def finish_trace(opts \\ []) do
        opts
        |> config(@otp_app)
        |> Spandex.finish_trace()
      end

      @impl Spandex.Tracer
      def finish_span(opts \\ []) do
        opts
        |> config(@otp_app)
        |> Spandex.finish_span()
      end

      @impl Spandex.Tracer
      def span_error(error, stacktrace, opts \\ []) do
        Spandex.span_error(error, stacktrace, config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def continue_trace(span_name, trace_id, span_id, opts \\ []) do
        Spandex.continue_trace(span_name, trace_id, span_id, config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def continue_trace_from_span(span_name, span, opts \\ []) do
        Spandex.continue_trace_from_span(span_name, span, config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def current_trace_id(opts \\ []) do
        Spandex.current_trace_id(config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def current_span_id(opts \\ []) do
        Spandex.current_span_id(config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def current_span(opts \\ []) do
        Spandex.current_span(config(opts, @otp_app))
      end

      @impl Spandex.Tracer
      def distributed_context(conn, opts \\ []) do
        Spandex.distributed_context(conn, config(opts, @otp_app))
      end

      defp config(opts, otp_app) do
        config =
          otp_app
          |> Application.get_env(__MODULE__)
          |> Kernel.||([])
          |> Keyword.merge(opts || [])
          |> Optimal.validate!(@opts)
          |> Keyword.put(:tracer, __MODULE__)

        if config[:disabled?] do
          :disabled
        else
          config
        end
      end

      defp validate_update_config(opts, otp_app) do
        env = Application.get_env(otp_app, __MODULE__)

        if env[:disabled] do
          :disabled
        else
          schema = %{@opts | defaults: [], required: []}

          # TODO: We may want to have some concept of "the quintessential tracer configs"
          # So that we can take those here, instead of embedding that knowledge here.

          opts
          |> Optimal.validate!(schema)
          |> Keyword.put(:tracer, __MODULE__)
          |> Keyword.put(:strategy, env[:strategy] || Spandex.Strategy.Pdict)
        end
      end
    end
  end
end
