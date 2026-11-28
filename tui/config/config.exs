import Config

if config_env() == :test do
  config :stratta, data_dir: Path.join(System.tmp_dir!(), "stratta-tui-test-#{System.unique_integer([:positive])}")
  config :logger, level: :warning
end
