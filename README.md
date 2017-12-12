# Spandex

[![Build Status](https://travis-ci.org/zachdaniel/spandex.svg?branch=master)](https://travis-ci.org/zachdaniel/spandex)
[![Inline docs](http://inch-ci.org/github/zachdaniel/spandex.svg)](http://inch-ci.org/github/zachdaniel/spandex)
[![Coverage Status](https://coveralls.io/repos/github/zachdaniel/spandex/badge.svg)](https://coveralls.io/github/zachdaniel/spandex)
[![Hex pm](http://img.shields.io/hexpm/v/spandex.svg?style=flat)](https://hex.pm/packages/spandex)
[![Deps Status](https://beta.hexfaktor.org/badge/all/github/zachdaniel/spandex.svg)](https://beta.hexfaktor.org/github/zachdaniel/spandex)
[![Ebert](https://ebertapp.io/github/zachdaniel/spandex.svg)](https://ebertapp.io/github/zachdaniel/spandex)

View the [documentation](https://hexdocs.pm/spandex)

Spandex is a platform agnostic tracing library. Currently there is only a datadog APM adapter, but its designed to be able to have more adapters written for it.

## Installation
```elixir
def deps do
  [{:spandex, "~> 1.2.7"}]
end
```
## Warning

Don't use the endpoint/channel configuration in your production environment. We saw a significant increase in scheduler/cpu load during high traffic times due to this feature. It was intended to provide a way to write custom visualizations by subscribing to a channel. We haven't removed it yet, but we probably will soon.

## Configuration

Spandex uses `Confex` under the hood. See the formats usable for declaring values at their [documentation](https://github.com/Nebo15/confex)

```elixir
config :spandex,
  service: :my_api, # required, default service name
  adapter: Spandex.Adapters.Datadog, # required
  disabled?: {:system, :boolean, "DISABLE_SPANDEX", false},
  env: {:system, "APM_ENVIRONMENT", "unknown"},
  application: :my_app,
  ignored_methods: ["OPTIONS"],
  # ignored routes accepts regexes, and strings. If it is a string it must match exactly.
  ignored_routes: [~r/health_check/, "/status"],
  # do not set the following configurations unless you are sure.
  log_traces?: false # You probably don't want this to be on, *especially* if you have high load. For debugging.
```

Even though datadog is the only adapter currently, configurations are still namespaced by the adapter to allow adding more in the future.

```elixir
config :spandex, :datadog,
  host: {:system, "DATADOG_HOST", "localhost"},
  port: {:system, "DATADOG_PORT", 8126},
  services: [ # for defaults mapping in spans service => type
    ecto: :db,
    my_api: :web,
    my_cache: :cache,
  ],
  # Do not set the following configurations unless you are sure.
  api_adapter: Spandex.Datadog.ApiServer, # Traces will get sent in background
  asynchronous_send?: true, # Defaults to `true`. no reason to change it except perhaps for testing purposes. If changed, expect performance impacts.
  endpoint: MyApp.Endpoint, # See notice about potential performance impacts from publishing traces to channels.
  channel: "spandex_traces", # If endpoint and channel are set, all traces will be broadcast across that channel
```

## Phoenix Plugs

There are 3 plugs provided for usage w/ Phoenix:

* `Spandex.Plug.StartTrace`
* `Spandex.Plug.AddContext`
* `Spandex.Plug.EndTrace`

Ensure that `Spandex.Plug.EndTrace` goes *after* your router. This is important because we want rendering the response to be included in the tracing/timing. Put `Spandex.Plug.StartTrace` as early as is reasonable in your pipeline. Put `Spandex.Plug.AddContext` either after router or inside a pipeline in router.


## Logger metadata
In general, you'll probably want the current span_id and trace_id in your logs, so that you can find them in your tracing service. Make sure to add `span_id` and `trace_id` to logger_metadata

```elixir
config :logger, :console,
  metadata: [:request_id, :trace_id, :span_id]
```

## General Usage

In general, the nicest interface is to use function decorators.

Span function decorators take an optional argument which is the attributes to update the span with.

```elixir
defmodule TracedModule do
  use Spandex.TraceDecorator

  @decorate trace(service: :my_app, type: :web)
  def trace_me() do
    span_1()
  end

  @decorate span()
  def span_1() do
    inner_span_1()
  end

  @decorate span()
  def inner_span_1() do
    _ = ThirdPartyApi.different_service_call()
    inner_span_2()
  end

  @decorate span()
  def inner_span_2() do
    "this produces the span stack you would expect"
  end
end

defmodule ThirdPartyApi do
  use Spandex.TraceDecorator

  @decorate span(service: :third_party, type: :cache)
  def different_service_call() do

  end
end
```

There is also a few ways to manually start spans.

```elixir
defmodule ManuallyTraced do
  require Spandex

  # Does not handle exceptions for you.
  def trace_me() do
    _ = Spandex.start_trace("my_trace") #also opens a span
    _ = Spandex.update_span(%{service: :my_app, type: :db})

    result = span_me()

    _ = Spandex.finish_trace()

    result
  end

  # Does not handle exceptions for you.
  def span_me() do
    _ = Spandex.start_span("this_span")
    _ = Spandex.update_span(%{service: :my_app, type: :web})

    result = span_me_also()

    _ = Spandex.finish_span()
  end

  # Handles exception at the span level. Trace still must be reported.
  def span_me_also() do
    Spandex.span("span_me_also) do
      ...
    end
  end
end
```

## Spandex.Logger

Logging can often incur unseen costs, especially for those unfamiliar with elixir's logging paradigm. For instance: Logger will eventually switch to a sync_mode once it reaches some limit of queued logs, which blocks the current process in order to apply backpressure. I highly recommend becoming very familiar with the Logger documentation to avoid missing gotchas like that. It's important to know how long it's taking to do IO, to know how long the functions you pass the authorizer are taking, and to determine how much of your application response time may be being eaten up by logging.

Tip: Use lists of strings, never concat or manually construct strings in the logger (or ideally anywhere else that is equipped to use iolists)

With that in mind, I've added `Spandex.Logger` which has a very similar interface to `Logger` but takes a `resource` (think of it as a title) as its first argument.
It also wraps any functions passed to logger in spans in order to report them, and prepends the `resource` to the beginning of the log message.

*IMPORTANT*
* Only accepts functions as the second parameter, not strings or lists, due to limitations in building the macro.
* Does *NOT* run the provided function if the log level does not line up or has been compile time purged, unlike the normal logger

Contributions to remove that badness are more then welcome.

```elixir
require Spandex.Logger

db_records = fetch_db_records!(id)

Spandex.Logger.info("Fetch Database Record", fn ->
  ["Fetched ", #{Enum.count(db_records)}, " records from the database."]
end)

# 11:23:15.334 [info]  Fetch Database Record: Fetched 10 records from the database
```

## Asynchronous Processes

Tasks are supported by using `Spandex.Task`

```elixir
Spandex.Task.async("foo", fn -> do_work() end)
```

Managing your own asynchronous work:

The current trace_id and span_id can be retrieved with `Spandex.current_trace_id()` and `Spandex.current_span_id()`. This can then be used as `Spandex.continue_trace("new_trace", trace_id, span_id)`. New spans can then be logged from there and will be sent in a separate batch.
