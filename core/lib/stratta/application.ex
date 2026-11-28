defmodule Stratta.Application do
  @moduledoc """
  Stratta's core: the daemon that owns agent sessions.

  Any BEAM node that starts this application is a Stratta daemon. Front ends
  either run in the same node (the LiveView GUI) or talk to it over the local
  control socket (`Stratta.Socket`, used by the `stratta` terminal client).
  """
  use Application

  @impl true
  def start(_type, _args) do
    register_demo_provider()

    children =
      [
        {Phoenix.PubSub, name: Stratta.PubSub},
        Stratta.Store,
        {Registry, keys: :unique, name: Stratta.ThreadRegistry},
        {DynamicSupervisor, name: Stratta.ThreadSupervisor, strategy: :one_for_one},
        {Task.Supervisor, name: Stratta.TaskSupervisor}
      ] ++ if(Application.get_env(:stratta, :socket, true), do: [Stratta.Socket], else: [])

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: Stratta.Supervisor) do
      Stratta.Threads.ensure_slots()
      {:ok, pid}
    end
  end

  defp register_demo_provider do
    providers = :jido_harness |> Application.get_env(:providers, %{}) |> Map.new()
    Application.put_env(:jido_harness, :providers, Map.put_new(providers, :demo, Stratta.DemoAdapter))
  end
end
