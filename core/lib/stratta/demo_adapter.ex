defmodule Stratta.DemoAdapter do
  @moduledoc """
  A Jido.Harness provider profile for Stratta's bundled demo ACP agent.

  The agent (`priv/demo_agent/demo_acp.py`) is a scripted fixture, not a
  model. It exercises streaming, thinking, plans, tool calls, permission
  requests, file edits, steering, interruption and model switching, so the
  whole UI can be tried without installing or paying for a real coding agent.
  """
  @behaviour Jido.Harness.Adapter

  alias Jido.Harness.{ACPAgentSpec, AdapterSpec, Capabilities, ProviderStatus}

  @impl true
  def spec do
    AdapterSpec.new!(
      provider: :demo,
      name: "Stratta Demo Agent",
      executable: script_path(),
      capabilities:
        Capabilities.new!(
          streaming?: true,
          tool_calls?: true,
          tool_results?: true,
          thinking?: true,
          resume?: true,
          usage?: true,
          file_changes?: true,
          native_cancel?: true
        ),
      acp_agent:
        ACPAgentSpec.native(script_path(), [], %{
          maturity: :experimental,
          capabilities: %{
            load_session: true,
            steer: true,
            interrupt: true,
            approvals: true,
            dynamic_model: true,
            usage: true
          },
          session_options: [:provider_session_id, :approval_mode],
          configuration_options: [:model]
        }),
      normalized_options: [:model, :provider_session_id, :approval_mode],
      provider_options: []
    )
  end

  @impl true
  def status(_config) do
    python = System.find_executable("python3")
    script = script_path()
    ready = not is_nil(python) and File.exists?(script)

    {:ok,
     ProviderStatus.new!(
       provider: :demo,
       installed: ready,
       compatible: ready,
       authenticated: true,
       smoke_ready: ready,
       session_ready: ready,
       version: "0.1.0",
       executable: script,
       capabilities: spec().capabilities,
       acp_agent: spec().acp_agent
     )}
  end

  @doc "Absolute path of the bundled demo agent script."
  def script_path, do: Application.app_dir(:stratta, "priv/demo_agent/demo_acp.py")
end
