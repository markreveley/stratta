defmodule StrattaTui.MixProject do
  use Mix.Project

  def project do
    [
      app: :stratta_tui,
      version: "0.2.0",
      elixir: "~> 1.19",
      deps: deps(),
      escript: [main_module: Stratta.TUI.CLI, name: "stratta"],
      aliases: [setup: ["deps.get", "escript.build"]]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [{:stratta, path: "../core", only: :test}] ++
      case System.get_env("STRATTA_VENDOR_DEPS") do
        nil -> [{:jason, "~> 1.4"}]
        dir -> vendored_deps(Path.expand(dir))
      end
  end

  @test_only ~w(jido_harness zoi decimal telemetry arbor_acp arbor_rpc phoenix_pubsub)a

  defp vendored_deps(dir) do
    test_only =
      for app <- @test_only do
        path =
          case app do
            :arbor_acp -> Path.join(dir, "arbor_acp_repo/packages/arbor_acp")
            other -> Path.join(dir, Atom.to_string(other))
          end

        {app, path: path, override: true, only: :test}
      end

    [{:jason, path: Path.join(dir, "jason"), override: true} | test_only]
  end
end
