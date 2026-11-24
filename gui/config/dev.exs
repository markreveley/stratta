import Config

config :stratta_gui, StrattaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4001")],
  check_origin: false,
  debug_errors: true,
  secret_key_base: "dev-only-secret-key-base-please-change-me-0123456789abcdefghijklmnopqrstuvwxyz"

config :phoenix, :plug_init_mode, :runtime
