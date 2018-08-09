# Spandex

[![Build Status](https://travis-ci.org/zachdaniel/spandex.svg?branch=master)](https://travis-ci.org/zachdaniel/spandex)
[![Inline docs](http://inch-ci.org/github/zachdaniel/spandex.svg)](http://inch-ci.org/github/zachdaniel/spandex)
[![Coverage Status](https://coveralls.io/repos/github/zachdaniel/spandex/badge.svg)](https://coveralls.io/github/zachdaniel/spandex)
[![Hex pm](http://img.shields.io/hexpm/v/spandex.svg?style=flat)](https://hex.pm/packages/spandex)
[![Ebert](https://ebertapp.io/github/zachdaniel/spandex.svg)](https://ebertapp.io/github/zachdaniel/spandex)

View the [documentation](https://hexdocs.pm/spandex)


## 2.0 Upgrade Guide

This is datadog specific since thats the only adapter.

* Include the adapter as a dependency (see below).
* Replace any occurrences of `Spandex.Adapters.Datadog` with `SpandexDatadog.Adapter` in your code.
* Replace any occurences of `Spandex.Adapters.ApiSender` with `SpandexDatadog.ApiSender` in your code.

## Adapters

* [Datadog](https://github.com/zachdaniel/spandex_datadog)
* Thats it so far! If you want another adapter it should be relatively easy to write! This library is in charge of handling the state management of spans, and the adapter is just in charge of generating certain values and ultimately sending the values to the service.

## Attention

This library could use some work! I've become unexpectedly busy lately, so I haven't had the time I thought I would to work on it. Any contributions, to things like sampling, strict mode, different storage strategies and the like would be greatly appreciated.

## Installation

```elixir
def deps do
  [{:spandex, "~> 1.6.2"}]
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
  adapter: My.Adapter,
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

For adapter configuration, see the documentation for that adapter

## Phoenix Plugs

There are 3 plugs provided for usage w/ Phoenix:

* `Spandex.Plug.StartTrace` - See moduledocs for options. Goes as early in your pipeline as possible.
* `Spandex.Plug.AddContext` - See moduledocs for options. Either after the router, or inside a pipeline in the router.
* `Spandex.Plug.EndTrace` - Must go *after* your router.

## Distributed Tracing

Individual adapters can support distributed tracing. See their documentation for more information.

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

```elixir
Spandex.update_span(type: :db, http: [url: "/posts", status_code: 400], sql_query: [query: "SELECT * FROM posts", rows: 10])
```

Spandex used to ship with function decorators, but those decorators had a habit of causing weird compilation issues for certain users, and could be easily implemented by any user of the library.

## Asynchronous Processes

The current trace_id and span_id can be retrieved with `Tracer.current_trace_id()` and `Tracer.current_span_id()`. This can then be used as `Tracer.continue_trace("new_trace", trace_id, span_id)`. New spans can then be logged from there and will be sent in a separate batch.

## Strategies

There is (currently and temporarily) only one storage strategy, which can be changed via the `strategy` option. See tracer opt documentation for an example of setting it. To implement your own (ETS adapter should be on its way) simply implement the `Spandex.Strategy` behaviour. Keep in mind that the strategy is not an atomic pattern. It represents retrieving and wholesale replacing a trace, meaning that it is *not* safe to use across processes or concurrently. Each process should have its own store for its own generated spans. This should be fine because you can send multiple batches of spans for the same trace separately.

## Ecto Tracing

I would like to see a separate library called `spandex_ecto` created to house the ecto specific code, but for now if you want it, an example implementation of an ecto logger that sends spandex data can be found in this issue: https://github.com/zachdaniel/spandex/issues/55. If anyone would like to make that repo, that would be a very nice contribution.
