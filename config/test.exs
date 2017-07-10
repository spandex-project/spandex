use Mix.Config

config :logger, :console,
  level: :debug,
  colors: [enabled: false]

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

config :exvcr,
  vcr_cassette_library_dir: "test/fixtures/vcr_cassettes",
  filter_request_headers: ~w[Authorization],
  filter_sensitive_data: [],
  filter_url_params: false,
  response_headers_blacklist: []
