import Config

config :logger, :console,
  level: :debug,
  colors: [enabled: false],
  format: "$time $metadata[$level] $message\n",
  metadata: [:trace_id, :span_id, :file, :line]

config :spandex, :decorators, tracer: Spandex.Test.Support.Tracer

config :spandex, Spandex.Test.Support.Tracer,
  service: :spandex_test,
  adapter: Spandex.TestAdapter,
  sender: Spandex.TestSender,
  env: "test",
  resource: "default",
  services: [
    spandex_test: :db
  ]

config :spandex, Spandex.Test.Support.OtherTracer,
  service: :spandex_test,
  adapter: Spandex.TestAdapter,
  sender: Spandex.TestSender,
  env: "test",
  resource: "default",
  services: [
    spandex_test: :db
  ]
