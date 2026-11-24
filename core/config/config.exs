import Config

# Core needs no configuration to run. Optional keys:
#
#   config :stratta,
#     data_dir: "~/.stratta",             # projects, threads, transcripts, socket
#     worktree_dir: ".stratta/worktrees", # per-thread worktrees, inside each project
#     socket: true                        # serve the local control socket
#
# STRATTA_DATA_DIR overrides data_dir at runtime.

config :logger, :default_formatter, format: "$time $metadata[$level] $message\n"

if config_env() == :test do
  config :stratta, data_dir: Path.join(System.tmp_dir!(), "stratta-core-test-#{System.unique_integer([:positive])}")
  config :logger, level: :warning
end
