import Config

config :logger, :default_formatter, format: "$time $metadata[$level] $message\n"

if config_env() == :test do
  config :stratta, data_dir: Path.join(System.tmp_dir!(), "stratta-core-test-#{System.unique_integer([:positive])}")
  config :logger, level: :warning
end
