defmodule StrattaGui.MixProject do
  use Mix.Project

  def project do
    [
      app: :stratta_gui,
      version: "0.2.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [setup: ["deps.get", "compile"]]
    ]
  end

  def application do
    [
      mod: {StrattaWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [{:stratta, path: "../core"}] ++
      case System.get_env("STRATTA_VENDOR_DEPS") do
        nil ->
          [
            {:phoenix, "~> 1.8"},
            {:phoenix_html, "~> 4.2"},
            {:phoenix_live_view, "~> 1.1"},
            {:bandit, "~> 1.6"},
            {:jason, "~> 1.4"}
          ]

        dir ->
          vendored_deps(Path.expand(dir))
      end
  end

  @vendored ~w(jido_harness zoi decimal jason telemetry arbor_acp arbor_rpc phoenix phoenix_pubsub
               phoenix_template phoenix_html phoenix_live_view plug plug_crypto mime websock
               websock_adapter bandit thousand_island hpax)a

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
