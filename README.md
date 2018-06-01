# Spandex

[![Build Status](https://travis-ci.org/zachdaniel/spandex.svg?branch=master)](https://travis-ci.org/zachdaniel/spandex)
[![Inline docs](http://inch-ci.org/github/zachdaniel/spandex.svg)](http://inch-ci.org/github/zachdaniel/spandex)
[![Coverage Status](https://coveralls.io/repos/github/zachdaniel/spandex/badge.svg)](https://coveralls.io/github/zachdaniel/spandex)
[![Hex pm](http://img.shields.io/hexpm/v/spandex.svg?style=flat)](https://hex.pm/packages/spandex)
[![Ebert](https://ebertapp.io/github/zachdaniel/spandex.svg)](https://ebertapp.io/github/zachdaniel/spandex)

View the [documentation](https://hexdocs.pm/spandex)

Spandex is a platform agnostic tracing library. Currently there is only a datadog APM adapter, but its designed to be able to have more adapters written for it.

This library is undergoing some structural changes for future versions. This documentation will be kept up to date, but if there are any inconsistencies, don't hesitate to make an issue.

## Installation

```elixir
def deps do
  [{:spandex, "~> 1.4.1"}]
end
```

## Setup and Configuration

Define your tracer:

```elixir
defmodule MyApp.Tracer do
  use Spandex.Tracer, otp_app: :mya_app
end
```

Configure it:

```elixir
config :my_app, MyApp.Tracer,
  service: :my_api,
  adapter: Spandex.Adapters.Datadog,
  disabled?: false,
  env: "PROD"
```

Or at runtime, by calling `configure/1` (usually in your application's startup)

```elixir
MyApp.Tracer.configure(disabled?: Mix.env == :test)
```

For more information on tracer configuration, view the docs for `Spandex.Tracer`. There you will find the documentation for the opts schema. The entire configuration can also be passed into each function in your tracer to be overridden if desired. For example:

`MyApp.Tracer.start_span("span_name", service: :some_special_service)`

Your configuration and the configuration in your config files is merged together, to avoid needing to specify this config at all times.

To bypass the tracer pattern entirely, you can call directly into the functions in `Spandex`, like `Spandex.start_span("span_name", [adapter: Foo, service: :bar])`

### Adapter specific configuration

To start the datadog adapter, add a worker to your application's supervisor

```elixir
# Example configuration
opts =
  [
    host: System.get_env("DATADOG_HOST") || "localhost",
    port: System.get_env("DATADOG_PORT") || 8126,
    batch_size: System.get_env("SPANDEX_BATCH_SIZE") || 10,
    sync_threshold: System.get_env("SPANDEX_SYNC_THRESHOLD") || 100,
    http: HTTPoison
  ]

# in your supervision tree

worker(Spandex.Datadog.ApiServer, [opts])
```

## Phoenix Plugs

There are 3 plugs provided for usage w/ Phoenix:

* `Spandex.Plug.StartTrace` - See moduledocs for options. Goes as early in your pipeline as possible.
* `Spandex.Plug.AddContext` - See moduledocs for options. Either after the router, or inside a pipeline in the router.
* `Spandex.Plug.EndTrace` - Must go *after* your router.

## Distributed Tracing

Distributed tracing is supported via headers `x-datadog-trace-id` and `x-datadog-parent-id`. If they are set, the `StartTrace` plug will act accordingly, continuing that trace and span instead of starting a new one. *Both* must be set for distributed tracing to work.

## Logger metadata

In general, you'll probably want the current span_id and trace_id in your logs, so that you can find them in your tracing service. Make sure to add `span_id` and `trace_id` to logger_metadata

```elixir
config :logger, :console,
  metadata: [:request_id, :trace_id, :span_id]
```

## General Usage

The nicest interface for working with spans is the `span` macro, illustrated in `span_me_also` below.

```elixir
defmodule ManuallyTraced do
  require Spandex

  # Does not handle exceptions for you.
  def trace_me() do
    _ = Tracer.start_trace("my_trace") #also opens a span
    _ = Tracer.update_span(service: :my_app, type: :db)

    result = span_me()

    _ = Tracer.finish_trace()

    result
  end

  # Does not handle exceptions for you.
  def span_me() do
    _ = Tracer.start_span("this_span")
    _ = Tracer.update_span(service: :my_app, type: :web)

    result = span_me_also()

    _ = Tracer.finish_span()
  end

  # Handles exception at the span level. Trace still must be reported.
  def span_me_also() do
    Tracer.span("span_me_also) do
      ...
    end
  end
end
```

### Metadata

See the module documentation for `Spandex.Span` as well as the documentation for the structs
contained as keys for that struct. They illustrate the keys that are known to either be common
keys or to have UI sugar with certain clients. Its hard to find any kind of list of these published
anywhere, so let me know if you know of more! Examples

```
Spandex.update_span(type: :db, http: [url: "/posts", status_code: 400], sql_query: [query: "SELECT * FROM posts", rows: 10])
```

Spandex used to ship with function decorators, but those decorators had a habit of causing weird compilation issues for certain users, and could be easily implemented by any user of the library.

## Asynchronous Processes

The current trace_id and span_id can be retrieved with `Tracer.current_trace_id()` and `Tracer.current_span_id()`. This can then be used as `Tracer.continue_trace("new_trace", trace_id, span_id)`. New spans can then be logged from there and will be sent in a separate batch.

## Datadog Api Sender Performance

Originally, the library had an api server and spans were sent via `GenServer.cast`, but we've seen the need to introduce backpressure, and limit the overall amount of requests made. As such, the datadog api sender accepts `batch_size` and `sync_threshold` options.

Batch size refers to *traces* not spans, so if you send a large amount of spans per trace, then you probably want to keep that number low. If you send only a few spans, then you could set it significantly higher.

Sync threshold refers to the *number of processes concurrently sending spans*. *NOT* the number of traces queued up waiting to be sent. It is used to apply backpressure while still taking advantage of parallelism. Ideally, the sync threshold would be set to a point that you wouldn't reasonably reach often, but that is low enough to not cause systemic performance issues if you don't apply backpressure. A simple way to think about it is that if you are seeing 1000 request per second, and your batch size is 10, then you'll be making 100 requests per second to datadog(probably a bad config). But if your sync_threshold is set to 10, you'll almost certainly exceed that because 100 requests in 1 second will likely overlap in that way. So when that is exceeded, the work is done synchronously, (not waiting for the asynchronous ones to complete even). This concept of backpressure is very important, and strategies for switching to synchronous operation are often surprisingly far more performant than purely asynchronous strategies (and much more predictable).
