use Mix.Config


config :spandex,
  service: :spandex_test,
  adapter: Spandex.Adapters.Datadog,
  disabled?: false,
  env: "test",
  application: :spandex,
  ignored_methods: ["OPTIONS"],
  ignored_routes: [~r/healthz/],
  log_traces?: false


config :spandex, :datadog,
  host: "datadog",
  port: 8126,
  services: [
    ecto: :sql,
    spandex_test: :job
  ],
  api_adapter: Spandex.Datadog.TestApiAdapter
