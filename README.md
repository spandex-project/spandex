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
  [{:spandex, "~> 1.1.0"}]
end
```

## Configuration

Spandex uses `Confex` under the hood. See the formats usable for declaring values at their [documentation](https://github.com/Nebo15/confex)

```elixir
config :spandex,
  service: :my_api, # required, default service name
  adapter: Spandex.Adapters.Datadog, # required
  disabled?: {:system, "DISABLE_SPANDEX", false},
  env: {:system, "APM_ENVIRONMENT", "unknown"},
  application: :my_app,
  ignored_methods: ["OPTIONS"],
  ignored_routes: [~r/health_check/],
  log_traces?: false # You probably don't want this to be on. This is helpful for debugging though.

config :spandex, :datadog,
  api_adapter: Spandex.Datadog.ApiServer, # Traces will get sent in background
  host: {:system, "DATADOG_HOST", "localhost"},
  port: {:system, "DATADOG_PORT", 8126},
  endpoint: MyApp.Endpoint,
  channel: "spandex_traces", # If endpoint and channel are set, all traces will be broadcast across that channel
  services: [ # for defaults mapping in spans service => type
    ecto: :db,
    my_api: :web,
    my_cache: :cache,
  ]
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


## Asynchronous Processes

Tasks are supported by using `Spandex.Task`

```elixir
Spandex.Task.async("foo", fn -> do_work() end)
```

Managing your own asynchronous work:

The current trace_id and span_id can be retrieved with `Spandex.current_trace_id()` and `Spandex.current_span_id()`. This can then be used as `Spandex.continue_trace("new_trace", trace_id, span_id)`. New spans can then be logged from there and will be sent in a separate batch.
