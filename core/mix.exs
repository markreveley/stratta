defmodule Stratta.MixProject do
  use Mix.Project

  def project do
    [
      app: :stratta,
      version: "0.2.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [setup: ["deps.get", "compile"]]
    ]
  end

  def application do
    [
      mod: {Stratta.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    case System.get_env("STRATTA_VENDOR_DEPS") do
      nil ->
        [
          {:jido_harness, github: "agentjido/jido_harness", branch: "main"},
          {:phoenix_pubsub, "~> 2.1"},
          {:jason, "~> 1.4"}
        ]

      dir ->
        vendored_deps(Path.expand(dir))
    end
  end

  @vendored ~w(jido_harness zoi decimal jason telemetry arbor_acp arbor_rpc phoenix_pubsub)a

  defp vendored_deps(dir) do
    for app <- @vendored do
      path =
        case app do
          :arbor_acp -> Path.join(dir, "arbor_acp_repo/packages/arbor_acp")
          other -> Path.join(dir, Atom.to_string(other))
        end

      {app, path: path, override: true}
    end
  end
end
