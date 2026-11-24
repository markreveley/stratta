import Config

if config_env() == :test do
  # The in-process daemon the tests talk to.
  config :stratta, data_dir: Path.join(System.tmp_dir!(), "stratta-tui-test-#{System.unique_integer([:positive])}")
  config :logger, level: :warning
end
