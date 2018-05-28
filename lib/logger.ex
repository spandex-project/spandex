defmodule Spandex.Logger do
  @moduledoc """
  Passes arguments on to the default logger, but wraps those calls in spans.
  When functions are provided, it wraps those functions in spans as well.
  """

  @doc """
  Mirrors calls to `Logger.error/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. The fourth argument is used to avoid sending logs that might be sent often or are unimportant. More info on levels in the documentation. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.

  *NOTICE*
  * Only accepts functions as its second parameter.
  * Does *NOT* run the provided function if the log level does not line up, unlike the normal logger
  """
  defmacro error(resource, fun, metadata \\ [], level \\ Spandex.default_level())

  defmacro error(resource, fun, metadata, level) do
    min_level = Application.get_env(:logger, :compile_time_purge_level, :debug)

    if Spandex.should_span?(level) do
      if Logger.compare_levels(:error, min_level) in [:gt, :eq] do
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          require Logger
          require Spandex

          if Logger.compare_levels(:error, Logger.level()) == :lt do
            :ok
          else
            Spandex.span "Logger" do
              Spandex.span "Logger.error", service: :logger, resource: resource do
                Logger.error(
                  fn ->
                    Spandex.span "Logger.error:anonymous_fn" do
                      [resource, ": ", fun.()]
                    end
                  end,
                  metadata
                )
              end
            end
          end
        end
      else
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          :ok
        end
      end
    else
      quote do
        require Logger

        Logger.error(
          fn ->
            [unquote(resource), ": ", unquote(fun).()]
          end,
          unquote(metadata)
        )
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.warn/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. The fourth argument is used to avoid sending logs that might be sent often or are unimportant. More info on levels in the documentation. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.

  *NOTICE*
  * Only accepts functions as its second parameter.
  * Does *NOT* run the provided function if the log level does not line up, unlike the normal logger
  """
  defmacro warn(resource, fun, metadata \\ [], level \\ Spandex.default_level())

  defmacro warn(resource, fun, metadata, level) do
    if Spandex.should_span?(level) do
      min_level = Application.get_env(:logger, :compile_time_purge_level, :debug)

      if Logger.compare_levels(:warn, min_level) in [:gt, :eq] do
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          require Logger
          require Spandex

          if Logger.compare_levels(:warn, Logger.level()) == :lt do
            :ok
          else
            Spandex.span "Logger" do
              Spandex.span "Logger.warn", service: :logger, resource: resource do
                Logger.warn(
                  fn ->
                    Spandex.span "Logger.warn:anonymous_fn" do
                      [resource, ": ", fun.()]
                    end
                  end,
                  metadata
                )
              end
            end
          end
        end
      else
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          :ok
        end
      end
    else
      quote do
        require Logger

        Logger.warn(
          fn ->
            [unquote(resource), ": ", unquote(fun).()]
          end,
          unquote(metadata)
        )
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.info/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. The fourth argument is used to avoid sending logs that might be sent often or are unimportant. More info on levels in the documentation.
  This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.

  *NOTICE*
  * Only accepts functions as its second parameter.
  * Does *NOT* run the provided function if the log level does not line up, unlike the normal logger
  """
  defmacro info(resource, fun, metadata \\ [], level \\ Spandex.default_level())

  defmacro info(resource, fun, metadata, level) do
    if Spandex.should_span?(level) do
      min_level = Application.get_env(:logger, :compile_time_purge_level, :debug)

      if Logger.compare_levels(:info, min_level) in [:gt, :eq] do
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          require Logger
          require Spandex

          if Logger.compare_levels(:info, Logger.level()) == :lt do
            :ok
          else
            Spandex.span "Logger" do
              Spandex.span "Logger.info", service: :logger, resource: resource do
                Logger.info(
                  fn ->
                    Spandex.span "Logger.info:anonymous_fn" do
                      [resource, ": ", fun.()]
                    end
                  end,
                  metadata
                )
              end
            end
          end
        end
      else
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          :ok
        end
      end
    else
      quote do
        require Logger

        Logger.info(
          fn ->
            [unquote(resource), ": ", unquote(fun).()]
          end,
          unquote(metadata)
        )
      end
    end
  end

  @doc """
  Mirrors calls to `Logger.debug/2`, but spans the calls

  The first argument: `resource`, is used to aggregate the data in trace tools,
  and sets the `resource` of the span. The fourth argument is used to avoid sending logs that might be sent often or are unimportant. More info on levels in the documentation. This also prepends the resource passed in
  to the message of your logs. This is made inexpensive by use of iolists, as
  opposed to actual string appending operations.

  *NOTICE*
  * Only accepts functions as its second parameter.
  * Does *NOT* run the provided function if the log level does not line up, unlike the normal logger
  """
  defmacro debug(resource, fun, metadata \\ [], level \\ Spandex.default_level())

  defmacro debug(resource, fun, metadata, level) do
    if Spandex.should_span?(level) do
      min_level = Application.get_env(:logger, :compile_time_purge_level, :debug)

      if Logger.compare_levels(:debug, min_level) in [:gt, :eq] do
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          require Logger
          require Spandex

          if Logger.compare_levels(:debug, Logger.level()) == :lt do
            :ok
          else
            Spandex.span "Logger" do
              Spandex.span "Logger.debug", service: :logger, resource: resource do
                Logger.debug(
                  fn ->
                    Spandex.span "Logger.debug:anonymous_fn" do
                      [resource, ": ", fun.()]
                    end
                  end,
                  metadata
                )
              end
            end
          end
        end
      else
        quote location: :keep, bind_quoted: [resource: resource, fun: fun, metadata: metadata] do
          :ok
        end
      end
    else
      quote do
        require Logger

        Logger.debug(
          fn ->
            [unquote(resource), ": ", unquote(fun).()]
          end,
          unquote(metadata)
        )
      end
    end
  end
end
