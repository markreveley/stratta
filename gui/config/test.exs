import Config

config :stratta_gui, StrattaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-only-secret-key-base-0123456789abcdefghijklmnopqrstuvwxyz0123456789",
  server: false

config :stratta, data_dir: Path.join(System.tmp_dir!(), "stratta-test-#{System.unique_integer([:positive])}")
config :logger, level: :warning
