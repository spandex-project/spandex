defmodule Spandex.Logger do
  @moduledoc """
  Passes arguments on to the default logger, but wraps those calls in spans.
  When functions are provided, it wraps those functions in spans as well.
  """

  @doc """
  Mirrors calls to `Logger.error/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.
  """
  defmacro error(resource, chardata_or_fun, metadata \\ [])
  defmacro error(resource, chardata_or_fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, chardata_or_fun: chardata_or_fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.error") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        if is_function(chardata_or_fun) do
          Logger.error(fn ->
            if self() == sender_pid do
              Spandex.span("Logger.error:anonymous_fn") do
                [resource, ": ", chardata_or_fun.()]
              end
            else
              Spandex.continue_trace_from_span("Logger.error:anonymous_fn")
              result = chardata_or_fun.()
              Spandex.finish_trace()
              [resource, ": ", result]
            end
          end, metadata)
        else
          Spandex.span("Logger.error") do
            Spandex.update_span(%{service: :logger, resource: resource})

            Logger.error([resource, ": ", chardata_or_fun], metadata)
          end
        end
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.warn/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.
  """
  defmacro warn(resource, chardata_or_fun, metadata \\ [])
  defmacro warn(resource, chardata_or_fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, chardata_or_fun: chardata_or_fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.warn") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        if is_function(chardata_or_fun) do
          Logger.warn(fn ->
            if self() == sender_pid do
              Spandex.span("Logger.warn:anonymous_fn") do
                [resource, ": ", chardata_or_fun.()]
              end
            else
              Spandex.continue_trace_from_span("Logger.warn:anonymous_fn")
              result = chardata_or_fun.()
              Spandex.finish_trace()
              [resource, ": ", result]
            end
          end, metadata)
        else
          Spandex.span("Logger.warn") do
            Spandex.update_span(%{service: :logger, resource: resource})

            Logger.warn([resource, ": ", chardata_or_fun], metadata)
          end
        end
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.info/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.
  """
  defmacro info(resource, chardata_or_fun, metadata \\ [])
  defmacro info(resource, chardata_or_fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, chardata_or_fun: chardata_or_fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.info") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        if is_function(chardata_or_fun) do
          Logger.info(fn ->
            if self() == sender_pid do
              Spandex.span("Logger.info:anonymous_fn") do
                [resource, ": ", chardata_or_fun.()]
              end
            else
              Spandex.continue_trace_from_span("Logger.info:anonymous_fn")
              result = chardata_or_fun.()
              Spandex.finish_trace()
              [resource, ": ", result]
            end
          end, metadata)
        else
          Spandex.span("Logger.info") do
            Spandex.update_span(%{service: :logger, resource: resource})

            Logger.info([resource, ": ", chardata_or_fun], metadata)
          end
        end
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.debug/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.
  """
  defmacro debug(resource, chardata_or_fun, metadata \\ [])
  defmacro debug(resource, chardata_or_fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, chardata_or_fun: chardata_or_fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.debug") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        if is_function(chardata_or_fun) do
          Logger.debug(fn ->
            if self() == sender_pid do
              Spandex.span("Logger.debug:anonymous_fn") do
                [resource, ": ", chardata_or_fun.()]
              end
            else
              Spandex.continue_trace_from_span("Logger.debug:anonymous_fn")
              result = chardata_or_fun.()
              Spandex.finish_trace()
              [resource, ": ", result]
            end
          end, metadata)
        else
          Spandex.span("Logger.debug") do
            Spandex.update_span(%{service: :logger, resource: resource})

            Logger.debug([resource, ": ", chardata_or_fun], metadata)
          end
        end
      end
    end
  end
end
