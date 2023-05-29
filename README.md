# ![Spandex](https://github.com/spandex-project/spandex/blob/master/static/spandex.png?raw=true)

[![GitHub Actions](https://github.com/github/docs/actions/workflows/main.yml/badge.svg)](https://github.com/spandex-project/spandex/actions)
[![Coverage Status](https://coveralls.io/repos/github/spandex-project/spandex/badge.svg)](https://coveralls.io/github/spandex-project/spandex)
[![Hex pm](http://img.shields.io/hexpm/v/spandex.svg?style=flat)](https://hex.pm/packages/spandex)
[![Total Download](https://img.shields.io/hexpm/dt/spandex.svg)](https://hex.pm/packages/spandex)
[![License](https://img.shields.io/hexpm/l/spandex.svg)](https://github.com/spandex-project/spandex/blob/master/LICENSE)

View the [documentation](https://hexdocs.pm/spandex)

Spandex is a library for tracing your elixir application. Tracing is a
monitoring tool that allows you get extremely granular information about the
runtime of your system. Using distributed tracing, you can also get a view of
how requests make their way through your entire ecosystem of microservices or
applications. Currently, Spandex only supports integrating with
[Datadog](https://www.datadoghq.com/), but it is built to be agnostic to what
platform you choose to view your trace data. Eventually it should support Open
Zipkin, Stackdriver, and any other trace viewer/aggregation tool you'd like to
integrate with. We are still under active development, working on moving to a
more standard/generic implementation of the internals. Contributions welcome!

## 3.0 Release

The 3.0 release only involves ensuring that you're using the latest adapter, which will be explicit in its dependency on a spandex version. This major version was done only to solve for breaking changes between the adapter and spandex core, in order to honor semver and also not break everyone's installation.

## 2.0 Upgrade Guide

This is Datadog-specific since that's currently the only adapter.

- Include the adapter as a dependency (see below).
- Replace any occurrences of `Spandex.Adapters.Datadog` with
  `SpandexDatadog.Adapter` in your code.
- Replace any occurrences of `Spandex.Adapters.ApiSender` with
  `SpandexDatadog.ApiSender` in your code.

## Adapters

- [Datadog](https://github.com/spandex-project/spandex_datadog)
- That's it so far! If you want another adapter, it should be relatively easy to
  write! This library is in charge of handling the state management of spans,
  and the adapter is just in charge of generating certain values and ultimately
  sending the values to the service.

## Installation

```elixir
def deps do
  [{:spandex, "~> 3.2"}]
end
```

## Setup and Configuration

Define your tracer:

```elixir
defmodule MyApp.Tracer do
  use Spandex.Tracer, otp_app: :my_app
end
```

Configure it:

```elixir
config :my_app, MyApp.Tracer,
  service: :my_api,
  adapter: SpandexDatadog.Adapter,
  disabled?: false,
  env: "PROD"
```

Or at runtime, by calling `configure/1` (usually in your application's startup)

```elixir
MyApp.Tracer.configure(disabled?: System.get_env("TRACE") != "true")
```

For more information on Tracer configuration, view the docs for
`Spandex.Tracer`. There you will find the documentation for the `opts` schema.
The entire configuration can also be passed into each function in your tracer
to be overridden if desired. For example:

`MyApp.Tracer.start_span("span_name", service: :some_special_service)`

Your configuration and the configuration in your config files are merged
together, to avoid needing to specify this config at all times.

To bypass the Tracer pattern entirely, you can call directly into the functions
in `Spandex`, like `Spandex.start_span("span_name", [adapter: Foo, service:
:bar])`. Note that in this case, you will need to specify all of the
configuration options in each call, because the Tracer is not managing the
defaults for you.

### Adapter specific configuration

For adapter configuration, see the documentation for that adapter

## Phoenix Plugs

There are 3 plugs provided for usage w/ Phoenix:

- `Spandex.Plug.StartTrace` - See module docs for options. Goes as early in your
  pipeline as possible.
- `Spandex.Plug.AddContext` - See moduledoc for options. Either after the
  router, or inside a pipeline in the router.
- `Spandex.Plug.EndTrace` - Must go _after_ your router.

## Distributed Tracing

Individual adapters can support distributed tracing. See their documentation
for more information.

## Logger metadata

In general, you'll probably want the current span_id and trace_id in your logs,
so that you can find them in your tracing service. Make sure to add `span_id`
and `trace_id` to logger_metadata

```elixir
config :logger, :console,
  metadata: [:request_id, :trace_id, :span_id]
```

## General Usage

The nicest interface for working with spans is the `span` macro, illustrated in
`span_me_also` below.

```elixir
defmodule ManuallyTraced do
  require Spandex

  # Does not handle exceptions for you.
  def trace_me() do
    Tracer.start_trace("my_trace") #also opens a span
    Tracer.update_span(service: :my_app, type: :db)

    result = span_me()

    Tracer.finish_trace()

    result
  end

  # Does not handle exceptions for you.
  def span_me() do
    Tracer.start_span("this_span")
    Tracer.update_span(service: :my_app, type: :web)

    result = span_me_also()

    Tracer.finish_span()
  end

  # Handles exception at the span level. Trace still must be reported.
  def span_me_also() do
    Tracer.span("span_me_also") do
      ...
    end
  end
end
```

### Metadata

See the module documentation for `Spandex.Span` as well as the documentation
for the structs contained as keys for that struct. They illustrate the keys
that are known to either be common keys or to have UI sugar with certain
clients. Its hard to find any kind of list of these published anywhere, so let
me know if you know of more!

For example:

```elixir
Spandex.update_span(
  type: :db,
  http: [url: "/posts", status_code: 400],
  sql_query: [query: "SELECT * FROM posts", rows: 10]
)
```

## Asynchronous Processes

The current `trace_id` and `span_id` can be retrieved and later used (for
example, from another process) as follows:

```elixir
trace_id = Tracer.current_trace_id()
span_id = Tracer.current_span_id()
span_context = %SpanContext{trace_id: trace_id, parent_id: span_id}
Tracer.continue_trace("new_trace", span_context)
```

New spans can then be logged from there and sent in a separate batch.

## Strategies

There is (currently and temporarily) only one storage strategy, which can be
changed via the `strategy` option. See Tracer opt documentation for an example
of setting it. To implement your own (ETS adapter should be on its way), simply
implement the `Spandex.Strategy` behaviour. Keep in mind that the strategy is
not an atomic pattern. It represents retrieving and wholesale replacing a
trace, meaning that it is _not_ safe to use across processes or concurrently.
Each process should have its own store for its own generated spans. This should
be fine because you can send multiple batches of spans for the same trace
separately.

## Decorators

Because the `decorator` library can cause conflicts when it interacts with other dependencies in the same project, we support it as an optional dependency. This allows you to disable it if it causes problems for you, but it also means that you need to explicitly include some version of `decorator` in your application's dependency list:

```elixir
# mix.exs

defp deps do
  [
    {:decorator, "~> 1.2"}
  ]
end
```

Then, configure the Spandex decorator with your default tracer:

```elixir
config :spandex, :decorators, tracer: MyApp.Tracer
```

Span function decorators take an optional argument which is the attributes to update the span with. One of those attributes can be the `:tracer` in case you want to override the default tracer (e.g., in case you want to use multiple tracers).

IMPORTANT If you define multiple clauses for a function, you'll have to decorate all of the ones you want to span.

```elixir
defmodule TracedModule do
  use Spandex.Decorators

  @decorate trace(service: :my_app, type: :web)
  def trace_me() do
    span_1()
  end

  @decorate span(name: "span_1")
  def span_1() do
    inner_span_1()
  end

  @decorate span()
  def inner_span_1() do
    _ = ThirdPartyApi.different_service_call()
    inner_span_2()
  end

  @decorate span(tracer: MyApp.OtherTracer)
  def inner_span_2() do
    "this produces a span stack to be reported by another tracer"
  end

  # Multiple Clauses
  @decorate span()
  def divide(n, 0), do: {:error, :divide_by_zero}
  @decorate span()
  def divide(n, m), do: n / m
end

defmodule ThirdPartyApi do
  use Spandex.Decorators

  @decorate span(service: :third_party, type: :cache)
  def different_service_call() do
    ...
  end
end
```

Note: Decorators don't magically do everything. It often makes a lot of sense to use `Tracer.update_span` from within your function to add details that are only available inside that same function.

## Ecto Tracing

Check out [spandex_ecto](https://github.com/spandex-project/spandex_ecto).

## Phoenix Tracing

Check out [spandex_phoenix](https://github.com/spandex-project/spandex_phoenix).

## Sampling and Rate Limiting

When the load or cost from tracing increases, it is useful to use rate limiting
or sampling to reduce tracing. When many traces are the same, it's enough to
trace only e.g. 10% of them, reducing the bill by 90% while still preserving
the ability to troubleshoot the system. The tracing still happens, but it
may not be sent to the monitoring service, or the service may drop it or not
retain detailed information.

Spandex stores the `priority` as an integer in the top level `Trace`.

In Datadog, there are four values:

- `MANUAL_KEEP`(2) indicates that the application wants to ensure that a trace is
  sampled, e.g. if there is an error
- `AUTO_KEEP` (1) indicates that a trace has been selected for sampling
- `AUTO_REJECT` (0) indicates that the trace has not been selected for sampling
- `MANUAL_REJECT` (-1) indicates that the application wants a trace to be dropped

Similarly, OpenTracing uses 0 and 1 to indicate that a trace is sampled.

In distributed tracing, multiple processes contribute to the same trace. When
sampling, the process that starts the trace can make a decision about whether
it should be sampled. It then passes that information to downstream processes
via an HTTP header.

A trace may be sampled out, i.e. priority of 0, but the application can
override the priority manually. This is usually done for requests with errors,
as they are the ones that need troubleshooting. You can also enable tracing
dynamically with a feature flag to debug a feature in production.

Spandex has functions to read and set the priority
(`Spandex.Tracer.current_priority/1` and `Spandex.Tracer.update_priority/2`).

The following code overrides the `span_error` function on the tracer to set the
priority to `MANUAL_KEEP` when there is an error on a trace:

```elixir
defmodule Foo.Tracer do
  use Spandex.Tracer, otp_app: :foo

  @impl Spandex.Tracer
  def span_error(error, stacktrace, opts) do
    super(error, stacktrace, opts)
    __MODULE__.update_priority(2)
  end
```

The specific details of priority and other sampling and rate limiting are specific
to the observability back end, so look to e.g.
[spandex_datadog](https://github.com/spandex-project/spandex_datadog) for details.
