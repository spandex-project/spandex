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

  *NOTICE* Only accepts functions as its second parameter.
  """
  defmacro error(resource, fun, metadata \\ [])
  defmacro error(resource, fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.error") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        Logger.error(fn ->
          if self() == sender_pid do
            Spandex.span("Logger.error:anonymous_fn") do
              [resource, ": ", fun.()]
            end
          else
            Spandex.continue_trace_from_span("Logger.error:anonymous_fn", current_span)
            result = fun.()
            Spandex.finish_trace()
            [resource, ": ", result]
          end
        end, metadata)
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.warn/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.

  *NOTICE* Only accepts functions as its second parameter.
  """
  defmacro warn(resource, fun, metadata \\ [])
  defmacro warn(resource, fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.warn") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        Logger.warn(fn ->
          if self() == sender_pid do
            Spandex.span("Logger.warn:anonymous_fn") do
              [resource, ": ", fun.()]
            end
          else
            Spandex.continue_trace_from_span("Logger.warn:anonymous_fn", current_span)
            result = fun.()
            Spandex.finish_trace()
            [resource, ": ", result]
          end
        end, metadata)
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.info/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.

  *NOTICE* Only accepts functions as its second parameter.
  """
  defmacro info(resource, fun, metadata \\ [])
  defmacro info(resource, fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.info") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        Logger.info(fn ->
          if self() == sender_pid do
            Spandex.span("Logger.info:anonymous_fn") do
              [resource, ": ", fun.()]
            end
          else
            Spandex.continue_trace_from_span("Logger.info:anonymous_fn", current_span)
            result = fun.()
            Spandex.finish_trace()
            [resource, ": ", result]
          end
        end, metadata)
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.debug/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.

  *NOTICE* Only accepts functions as its second parameter.
  """
  defmacro debug(resource, fun, metadata \\ [])
  defmacro debug(resource, fun, metadata) do
    quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
      require Logger
      require Spandex
      Spandex.span("Logger.debug") do
        Spandex.update_span(%{service: :logger, resource: resource})

        current_span = Spandex.current_span()
        sender_pid = self()
        Logger.debug(fn ->
          if self() == sender_pid do
            Spandex.span("Logger.debug:anonymous_fn") do
              [resource, ": ", fun.()]
            end
          else
            Spandex.continue_trace_from_span("Logger.debug:anonymous_fn", current_span)
            result = fun.()
            Spandex.finish_trace()
            [resource, ": ", result]
          end
        end, metadata)
      end
    end
  end
end
