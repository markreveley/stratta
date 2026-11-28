import Config

config :stratta_gui, StrattaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: StrattaWeb.ErrorHTML], layout: false],
  pubsub_server: Stratta.PubSub,
  live_view: [signing_salt: "stratta-lv-salt"]

config :logger, :default_formatter, format: "$time $metadata[$level] $message\n"
config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
