use Mix.Config

# TODO: Update this!

config :logger, :console,
  level: :debug,
  colors: [enabled: false],
  format: "$time $metadata[$level] $message\n",
  metadata: [:trace_id, :span_id]

config :spandex, Spandex.Test.Support.Tracer,
  service: :spandex_test,
  adapter: Spandex.Adapters.Datadog,
  env: "test",
  sender: Spandex.Test.DatadogTestApiServer
