# Spandex

[![Build Status](https://travis-ci.org/zachdaniel/spandex.svg?branch=master)](https://travis-ci.org/zachdaniel/spandex)
[![Inline docs](http://inch-ci.org/github/zachdaniel/spandex.svg)](http://inch-ci.org/github/zachdaniel/spandex)
[![Coverage Status](https://coveralls.io/repos/github/zachdaniel/spandex/badge.svg)](https://coveralls.io/github/zachdaniel/spandex)
[![Hex pm](http://img.shields.io/hexpm/v/spandex.svg?style=flat)](https://hex.pm/packages/spandex)
[![Ebert](https://ebertapp.io/github/zachdaniel/spandex.svg)](https://ebertapp.io/github/zachdaniel/spandex)

View the [documentation](https://hexdocs.pm/spandex)

Spandex is a platform agnostic tracing library. Currently there is only a datadog APM adapter, but its designed to be able to have more adapters written for it.

## Installation
```elixir
def deps do
  [{:spandex, "~> 1.3.4"}]
end
```
## Warning

Don't use the endpoint/channel configuration in your production environment. We saw a significant increase in scheduler/cpu load during high traffic times due to this feature. It was intended to provide a way to write custom visualizations by subscribing to a channel. We haven't removed it yet, but we probably will soon.

## Performance

Originally, the library had an api server and spans were sent via `GenServer.cast`, but we've seen the need to introduce backpressure, and limit the overall amount of requests made. As such, there are two new configuration options (also shown in the configuration section below)

```elixir
config :spandex, :datadog,
  batch_size: 10,
  sync_threshold: 20,
  max_interval: 8
```

Batch size refers to *traces* not spans, so if you send a large amount of spans per trace, then you probably want to keep that number low. If you send only a few spans, then you could set it significantly higher.

Sync threshold refers to the *number of processes concurrently sending spans*. *NOT* the number of traces queued up waiting to be sent. It is used to apply backpressure while still taking advantage of parallelism. Ideally, the sync threshold would be set to a point that you wouldn't reasonably reach often, but that is low enough to not cause systemic performance issues if you don't apply backpressure. A simple way to think about it is that if you are seeing 1000 request per second, and your batch size is 10, then you'll be making 100 requests per second to datadog(probably a bad config). But if your sync_threshold is set to 10, you'll almost certainly exceed that because 100 requests in 1 second will likely overlap in that way. So when that is exceeded, the work is done synchronously, (not waiting for the asynchronous ones to complete even). This concept of backpressure is very important, and strategies for switching to synchronous operation are often surprisingly far more performant than purely asynchronous strategies (and much more predictable).

Max interval refers to the maximum period of time in seconds between sending traces. When there is low load, and you have fewer than `batch_size` traces waiting, the the traces will be sent after `max_interval`. This is important in the case of Datadog, whose agent discards traces received more than 10 seconds after they began. You should configure this to 10 or lower if this is a concern, otherwise `:infinity` will disable this periodic flush. The default is 10 seconds.

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
  batch_size: 10,
  sync_threshold: 20,
  max_interval: 10,
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

`Spandex.Plug.AddContext` can be modified to include options for `:allowed_route_replacements` and `:disallowed_route_replacements`, so a route of `:base_route/:id/:relationship` would only have `:base_route` and `:relationship` swapped to their param values if included in `:allowed_route_replacements` and not included in `:disallowed_route_replacements`.

Ensure that `Spandex.Plug.EndTrace` goes *after* your router. This is important because we want rendering the response to be included in the tracing/timing. Put `Spandex.Plug.StartTrace` as early as is reasonable in your pipeline. Put `Spandex.Plug.AddContext` either after router or inside a pipeline in router.

## Distributed Tracing

Distributed tracing is supported via headers `x-datadog-trace-id` and `x-datadog-parent-id`. If they are set, the `StartTrace` plug will act accordingly, continuing that trace and span instead of starting a new one. *Both* must be set for distributed tracing to work.

## Logger metadata
In general, you'll probably want the current span_id and trace_id in your logs, so that you can find them in your tracing service. Make sure to add `span_id` and `trace_id` to logger_metadata

```elixir
config :logger, :console,
  metadata: [:request_id, :trace_id, :span_id]
```

## General Usage

In general, the nicest interface is to use function decorators.

Span function decorators take an optional argument which is the attributes to update the span with.

*IMPORTANT*
If you define multiple clauses for a function, you'll have to decorate all of the ones you want to span.

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

  # Multiple Clauses
  @decorate span()
  def divide(n, 0), do: {:error, :divide_by_zero}
  @decorate span()
  def divide(n, m), do: n / m
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

## Ecto Logger

See module documentation for `Spandex.Ecto.Trace` for more information

A trace builder that can be given to ecto as a logger. It will try to get
the trace_id and span_id from the caller pid in the case that the particular
query is being run asynchronously (as in the case of parallel preloads).

Traces will default to the service name `:ecto` but can be configured.

config :spandex, :ecto,
  service: :my_ecto

To configure, set it up as an ecto logger like so:

config :my_app, MyApp.Repo,
  loggers: [{Ecto.LogEntry, :log, [:info]}, {Spandex.Ecto.Trace, :trace, []}]

## Asynchronous Processes

The current trace_id and span_id can be retrieved with `Spandex.current_trace_id()` and `Spandex.current_span_id()`. This can then be used as `Spandex.continue_trace("new_trace", trace_id, span_id)`. New spans can then be logged from there and will be sent in a separate batch.
