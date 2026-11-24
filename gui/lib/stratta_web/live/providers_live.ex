defmodule StrattaWeb.ProvidersLive do
  use StrattaWeb, :live_view

  alias Stratta.Providers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Providers", specs: Providers.specs(), statuses: nil, plan: nil)
     |> start_async(:statuses, fn -> Providers.statuses() end)}
  end

  @impl true
  def handle_async(:statuses, {:ok, s}, socket), do: {:noreply, assign(socket, statuses: s)}
  def handle_async(:statuses, _, socket), do: {:noreply, assign(socket, statuses: %{})}

  @impl true
  def handle_event("refresh", _, socket),
    do: {:noreply, socket |> assign(statuses: nil) |> start_async(:statuses, fn -> Providers.refresh() end)}

  def handle_event("plan", %{"provider" => p}, socket) do
    provider = String.to_existing_atom(p)
    {:noreply, assign(socket, plan: {provider, Providers.install_plan(provider)})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="providers-page">
      <div class="row between">
        <div>
          <.link navigate={~p"/"} class="muted">← Back</.link>
          <h1>Coding agents</h1>
          <p class="muted">
            Provider profiles bundled with <code>Jido.Harness {Jido.Harness.version()}</code>.
            Status checks never send a prompt. Sign in with each CLI's own login; Stratta never stores credentials.
          </p>
        </div>
        <button class="btn" phx-click="refresh">↻ Re-check</button>
      </div>

      <table class="ptable">
        <thead>
          <tr>
            <th>Agent</th><th>CLI</th><th>ACP entry point</th><th>Installed</th><th>Auth</th><th>Status</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={s <- @specs}>
            <% st = @statuses && @statuses[s.provider] %>
            <td><.provider_badge provider={Atom.to_string(s.provider)} /> {s.name}
              <span :if={s.acp_agent && s.acp_agent.maturity == :experimental} class="chip small">experimental</span></td>
            <td><code>{Path.basename(s.executable)}</code></td>
            <td>
              <code>{s.acp_agent && Path.basename(s.acp_agent.executable)} {s.acp_agent && Enum.join(s.acp_agent.argv, " ")}</code>
            </td>
            <td>{yes(st, :installed)}</td>
            <td>{auth(st)}</td>
            <td><span class={["chip", Providers.ready?(st) && "chip-ok"]}>{Providers.label(st)}</span></td>
            <td>
              <button :if={s.provider != :demo} class="mini" phx-click="plan" phx-value-provider={s.provider}>install plan</button>
            </td>
          </tr>
        </tbody>
      </table>

      <div :if={@plan} class="plan-box">
        <b>Install plan for {elem(@plan, 0)}</b>
        <span class="muted">(dry run — run <code>Jido.Harness.install(:{elem(@plan, 0)})</code>
        in <code>iex -S mix</code>
        to apply)</span>
        <pre>{inspect(elem(@plan, 1), pretty: true, limit: :infinity)}</pre>
      </div>
    </div>
    """
  end

  defp yes(%Jido.Harness.ProviderStatus{} = st, key), do: if(Map.get(st, key), do: "✓", else: "—")
  defp yes(nil, _), do: "…"
  defp yes(_, _), do: "?"

  defp auth(%Jido.Harness.ProviderStatus{authenticated: true}), do: "✓"
  defp auth(%Jido.Harness.ProviderStatus{authenticated: false}), do: "—"
  defp auth(%Jido.Harness.ProviderStatus{}), do: "unknown"
  defp auth(nil), do: "…"
  defp auth(_), do: "?"
end
