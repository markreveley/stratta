defmodule StrattaWeb.AppLive do
  use StrattaWeb, :live_view

  alias Stratta.{Providers, Threads, ThreadServer}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Stratta.PubSub, "threads")

    socket =
      socket
      |> assign(
        projects: Threads.list_projects(),
        threads: Threads.list_threads(),
        statuses: %{},
        provider_statuses: nil,
        specs: Providers.specs(),
        thread: nil,
        snap: nil,
        diff: nil,
        panel: nil,
        pr_draft: nil,
        project_error: nil,
        form_error: nil,
        new_form: %{"provider" => "demo", "worktree" => "true"},
        composer: ""
      )
      |> start_async(:provider_statuses, fn -> Providers.statuses() end)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"thread_id" => id}, _uri, socket) do
    if old = socket.assigns.thread, do: Phoenix.PubSub.unsubscribe(Stratta.PubSub, ThreadServer.topic(old["id"]))

    case Threads.get_thread(id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Thread not found") |> push_patch(to: ~p"/")}

      thread ->
        if connected?(socket), do: Phoenix.PubSub.subscribe(Stratta.PubSub, ThreadServer.topic(id))
        snap = if connected?(socket), do: ThreadServer.snapshot(id)

        {:noreply,
         socket
         |> assign(thread: thread, snap: snap, diff: nil, pr_draft: nil, page_title: thread["title"])
         |> maybe_load_diff()}
    end
  end

  def handle_params(_params, _uri, socket) do
    if old = socket.assigns.thread, do: Phoenix.PubSub.unsubscribe(Stratta.PubSub, ThreadServer.topic(old["id"]))
    {:noreply, assign(socket, thread: nil, snap: nil, page_title: "Stratta")}
  end

  # -- pubsub -----------------------------------------------------------------

  @impl true
  def handle_info({:thread, id, snap}, %{assigns: %{thread: %{"id" => id}}} = socket) do
    was_busy = socket.assigns.snap && socket.assigns.snap.status in [:running, :awaiting_approval]
    socket = assign(socket, snap: snap, thread: snap.thread)

    socket =
      if was_busy and snap.status == :idle, do: maybe_load_diff(socket), else: socket

    {:noreply, socket}
  end

  def handle_info({:thread, _id, _snap}, socket), do: {:noreply, socket}

  def handle_info({:thread_status, id, status, thread}, socket) do
    threads =
      Enum.map(socket.assigns.threads, fn
        %{"id" => ^id} -> thread
        t -> t
      end)

    {:noreply, assign(socket, statuses: Map.put(socket.assigns.statuses, id, status), threads: threads)}
  end

  def handle_info(:threads_changed, socket),
    do: {:noreply, assign(socket, threads: Threads.list_threads(), projects: Threads.list_projects())}

  @impl true
  def handle_async(:provider_statuses, {:ok, statuses}, socket),
    do: {:noreply, assign(socket, provider_statuses: statuses)}

  def handle_async(:provider_statuses, _, socket), do: {:noreply, assign(socket, provider_statuses: %{})}

  def handle_async(:diff, {:ok, diff}, socket), do: {:noreply, assign(socket, diff: diff)}
  def handle_async(:diff, _, socket), do: {:noreply, assign(socket, diff: [])}

  # -- events: projects & threads ---------------------------------------------

  @impl true
  def handle_event("add_project", %{"path" => path}, socket) do
    case Threads.add_project(path) do
      {:ok, project} ->
        Threads.broadcast_list()
        form = Map.put(socket.assigns.new_form, "project_id", project["id"])

        {:noreply,
         assign(socket, projects: Threads.list_projects(), project_error: nil, new_form: form) |> push_patch(to: ~p"/")}

      {:error, msg} ->
        {:noreply, assign(socket, project_error: msg)}
    end
  end

  def handle_event("remove_project", %{"id" => id}, socket) do
    Threads.remove_project(id)

    {:noreply,
     socket |> assign(projects: Threads.list_projects(), threads: Threads.list_threads()) |> push_patch(to: ~p"/")}
  end

  def handle_event("new_thread_for", %{"project" => pid}, socket) do
    {:noreply, socket |> assign(new_form: Map.put(socket.assigns.new_form, "project_id", pid)) |> push_patch(to: ~p"/")}
  end

  def handle_event("form_change", params, socket),
    do: {:noreply, assign(socket, new_form: Map.merge(socket.assigns.new_form, params))}

  def handle_event("create_thread", params, socket) do
    project = Threads.get_project(params["project_id"] || "")

    cond do
      is_nil(project) ->
        {:noreply, assign(socket, form_error: "Choose a project first.")}

      true ->
        case Threads.create_thread(project, params) do
          {:ok, thread} ->
            first = String.trim(params["message"] || "")
            if first != "", do: Task.start(fn -> ThreadServer.send_input(thread["id"], first) end)

            {:noreply,
             socket
             |> assign(form_error: nil, threads: Threads.list_threads())
             |> push_patch(to: ~p"/t/#{thread["id"]}")}

          {:error, msg} ->
            {:noreply, assign(socket, form_error: msg)}
        end
    end
  end

  def handle_event("delete_thread", _params, socket) do
    Threads.delete_thread(socket.assigns.thread["id"])
    {:noreply, socket |> assign(threads: Threads.list_threads()) |> push_patch(to: ~p"/")}
  end

  def handle_event("handoff", %{"provider" => provider}, socket) when provider != "" do
    {:ok, new} = Threads.handoff(socket.assigns.thread, provider)
    {:noreply, push_patch(socket, to: ~p"/t/#{new["id"]}")}
  end

  def handle_event("handoff", _params, socket), do: {:noreply, socket}

  # -- events: conversation ---------------------------------------------------

  def handle_event("send", %{"text" => text} = params, socket) do
    text = String.trim(text)
    mode = if params["mode"] == "steer", do: :steer, else: :auto

    if text != "" do
      id = socket.assigns.thread["id"]
      # The first message may start a CLI, which can take a few seconds.
      Task.start(fn -> ThreadServer.send_input(id, text, mode) end)
    end

    {:noreply, assign(socket, composer: "") |> push_event("composer:clear", %{})}
  end

  def handle_event("interrupt", _params, socket) do
    ThreadServer.interrupt(socket.assigns.thread["id"])
    {:noreply, socket}
  end

  def handle_event("approval", %{"request_id" => rid, "decision" => d}, socket) do
    decision = if d == "approve", do: :approve, else: :deny
    ThreadServer.respond_approval(socket.assigns.thread["id"], rid, decision)
    {:noreply, socket}
  end

  def handle_event("set_model", %{"model" => model}, socket) do
    id = socket.assigns.thread["id"]
    Task.start(fn -> ThreadServer.set_model(id, String.trim(model)) end)
    {:noreply, socket}
  end

  # -- events: git ------------------------------------------------------------

  def handle_event("panel", %{"name" => name}, socket) do
    panel = if socket.assigns.panel == name, do: nil, else: name
    socket = assign(socket, panel: panel)

    socket =
      case panel do
        "diff" ->
          load_diff(socket)

        "ship" ->
          socket |> load_diff() |> assign(pr_draft: Threads.draft_pr(socket.assigns.thread, socket.assigns.snap.items))

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("refresh_diff", _, socket), do: {:noreply, load_diff(socket)}

  def handle_event("commit", %{"message" => msg}, socket) do
    msg = if String.trim(msg) == "", do: socket.assigns.thread["title"], else: msg
    Threads.commit(socket.assigns.thread, msg)
    {:noreply, load_diff(socket)}
  end

  def handle_event("push", _, socket) do
    thread = socket.assigns.thread
    Task.start(fn -> Threads.push(thread) end)
    {:noreply, socket}
  end

  def handle_event("ship", params, socket) do
    thread = socket.assigns.thread
    Task.start(fn -> Threads.ship(thread, params) end)
    {:noreply, assign(socket, panel: nil)}
  end

  # -- helpers ----------------------------------------------------------------

  defp maybe_load_diff(%{assigns: %{panel: p}} = socket) when p in ["diff", "ship"], do: load_diff(socket)
  defp maybe_load_diff(socket), do: socket

  defp load_diff(%{assigns: %{thread: %{"cwd" => _} = thread}} = socket) do
    if Stratta.Git.repo?(thread["cwd"]),
      do: start_async(socket, :diff, fn -> Threads.diff(thread) end),
      else: assign(socket, diff: :not_git)
  end

  defp load_diff(socket), do: socket

  defp thread_status(assigns, thread) do
    Map.get(assigns.statuses, thread["id"]) || :detached
  end

  defp busy?(nil), do: false
  defp busy?(snap), do: snap.status in [:running, :awaiting_approval]

  defp project_threads(threads, project), do: Enum.filter(threads, &(&1["project_id"] == project["id"]))

  defp spec_for(specs, provider), do: Enum.find(specs, &(Atom.to_string(&1.provider) == provider))

  defp option?(specs, provider, opt) do
    case spec_for(specs, provider) do
      nil -> false
      spec -> opt in Providers.session_options(spec)
    end
  end

  defp values(specs, provider, field, default) do
    (spec_for(specs, provider) && Providers.allowed_values(spec_for(specs, provider), field)) || default
  end

  defp diff_totals(files) when is_list(files),
    do: {length(files), Enum.sum(Enum.map(files, & &1.additions)), Enum.sum(Enum.map(files, & &1.deletions))}

  defp diff_totals(_), do: {0, 0, 0}

  # -- render -----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["app", @thread && @panel && "with-panel"]}>
      <aside class="sidebar">
        <div class="brand">
          <.link patch={~p"/"} class="logo"><span class="logo-mark">⌘</span> stratta</.link>
          <.link navigate={~p"/providers"} class="icon-link" title="Providers">⚙</.link>
        </div>
        <.link patch={~p"/"} class="btn btn-new">+ New thread</.link>

        <div class="projects">
          <div :for={p <- @projects} class="project">
            <div class="project-head">
              <span class="project-name" title={p["path"]}>{p["name"]}</span>
              <span class="project-actions">
                <button class="mini" phx-click="new_thread_for" phx-value-project={p["id"]} title="New thread">+</button>
                <button
                  class="mini"
                  phx-click="remove_project"
                  phx-value-id={p["id"]}
                  data-confirm={"Remove #{p["name"]} and its threads from Stratta? Files are not deleted."}
                  title="Remove"
                >×</button>
              </span>
            </div>
            <.link
              :for={t <- project_threads(@threads, p)}
              patch={~p"/t/#{t["id"]}"}
              class={["thread-link", @thread && @thread["id"] == t["id"] && "active"]}
            >
              <.status_dot status={thread_status(assigns, t)} />
              <span class="thread-title">{t["title"]}</span>
              <.provider_badge provider={t["provider"]} />
            </.link>
            <div :if={project_threads(@threads, p) == []} class="muted small pad-l">No threads yet</div>
          </div>
        </div>

        <form phx-submit="add_project" class="add-project">
          <input name="path" placeholder="Add project: /path/to/repo" autocomplete="off" />
          <div :if={@project_error} class="err small">{@project_error}</div>
        </form>
      </aside>

      <main class="main">
        <%= if @thread do %>
          {render_thread(assigns)}
        <% else %>
          {render_new(assigns)}
        <% end %>
      </main>

      <aside :if={@thread && @panel} class="panel">
        {render_panel(assigns)}
      </aside>
    </div>
    """
  end

  defp render_new(assigns) do
    ~H"""
    <div class="new-thread">
      <h1>What should we build?</h1>
      <p class="muted">
        Pick a project and a coding agent. Every agent runs through <code>Jido.Harness</code>
        over ACP, using the CLI login you already have.
      </p>

      <div :if={@projects == []} class="empty-card">
        <b>Add a project to begin.</b>
        <p class="muted">
          Paste a folder path in the sidebar. Git repos get per-thread worktrees and the commit → push → PR flow.
        </p>
        <form phx-submit="add_project" class="row">
          <input name="path" placeholder="/Users/you/code/my-app" autocomplete="off" />
          <button class="btn btn-primary">Add</button>
        </form>
      </div>

      <form :if={@projects != []} phx-submit="create_thread" phx-change="form_change" class="new-form">
        <textarea
          name="message"
          rows="4"
          placeholder="Describe the task… (optional — you can also start empty)"
          phx-hook="Composer"
          id="new-msg"
        >{@new_form["message"]}</textarea>

        <div class="grid">
          <label>
            Project
            <select name="project_id">
              <option :for={p <- @projects} value={p["id"]} selected={@new_form["project_id"] == p["id"]}>
                {p["name"]}
              </option>
            </select>
          </label>

          <label>
            Agent
            <select name="provider">
              <option :for={s <- @specs} value={s.provider} selected={@new_form["provider"] == Atom.to_string(s.provider)}>
                {s.name} · {Providers.label(@provider_statuses && @provider_statuses[s.provider])}
              </option>
            </select>
          </label>

          <label :if={option?(@specs, @new_form["provider"], :model)}>
            Model <span class="muted small">(blank = provider default)</span>
            <input
              name="model"
              value={@new_form["model"]}
              placeholder={if @new_form["provider"] == "demo", do: "demo-fast", else: "e.g. sonnet, gpt-5-codex"}
            />
          </label>

          <label :if={option?(@specs, @new_form["provider"], :approval_mode)}>
            Approvals
            <select name="approval_mode">
              <option
                :for={
                  m <- values(@specs, @new_form["provider"], :approval_mode, [:default, :prompt, :auto_edit, :auto_approve])
                }
                value={m}
                selected={@new_form["approval_mode"] == to_string(m)}
              >
                {m}
              </option>
            </select>
          </label>

          <label :if={option?(@specs, @new_form["provider"], :sandbox_mode)}>
            Sandbox
            <select name="sandbox_mode">
              <option
                :for={
                  m <-
                    values(@specs, @new_form["provider"], :sandbox_mode, [
                      :default,
                      :read_only,
                      :workspace_write,
                      :unrestricted
                    ])
                }
                value={m}
                selected={@new_form["sandbox_mode"] == to_string(m)}
              >
                {m}
              </option>
            </select>
          </label>

          <label class="check">
            <input type="hidden" name="worktree" value="false" />
            <input type="checkbox" name="worktree" value="true" checked={@new_form["worktree"] == "true"} />
            Isolate in a new branch + git worktree
          </label>
        </div>

        <div :if={@form_error} class="err">{@form_error}</div>
        <div class="row end">
          <button class="btn btn-primary">Start thread</button>
        </div>
      </form>
    </div>
    """
  end

  defp render_thread(assigns) do
    spec = spec_for(assigns.specs, assigns.thread["provider"])
    snap = assigns.snap || %{items: [], status: :detached, live_model: nil, usage: nil, queued: 0}
    assigns = assign(assigns, spec: spec, s: snap, busy: busy?(snap), totals: diff_totals(assigns.diff))

    ~H"""
    <header class="thread-head">
      <div class="th-left">
        <.status_dot status={@s.status} />
        <h2 title={@thread["title"]}>{@thread["title"]}</h2>
        <span class="chip">{(@spec && @spec.name) || @thread["provider"]}</span>
        <span :if={@thread["branch"]} class="chip chip-branch" title={@thread["cwd"]}>⑂ {@thread["branch"]}</span>
        <a :if={@thread["pr_url"]} href={@thread["pr_url"]} target="_blank" class="chip chip-pr">PR ↗</a>
      </div>
      <div class="th-right">
        <form :if={@spec && Providers.can_switch_model?(@spec)} phx-submit="set_model" class="model-form">
          <input name="model" value={@s.live_model || @thread["model"]} placeholder="model" title="Switch model mid-thread" />
        </form>
        <form phx-change="handoff" class="handoff">
          <select name="provider" title="Hand off to another agent in the same worktree">
            <option value="">Hand off…</option>
            <option :for={sp <- @specs} :if={Atom.to_string(sp.provider) != @thread["provider"]} value={sp.provider}>
              {sp.name}
            </option>
          </select>
        </form>
        <button class={["btn", @panel == "diff" && "on"]} phx-click="panel" phx-value-name="diff">
          Diff <span :if={elem(@totals, 0) > 0} class="count">{elem(@totals, 0)}</span>
        </button>
        <button class={["btn btn-primary", @panel == "ship" && "on"]} phx-click="panel" phx-value-name="ship">Ship</button>
        <button
          class="btn btn-ghost"
          phx-click="delete_thread"
          data-confirm="Delete this thread? Its worktree is removed too."
        >🗑</button>
      </div>
    </header>

    <section class="timeline" id="timeline" phx-hook="ScrollBottom">
      <div :if={@s.items == []} class="titem empty-thread">
        <p>Thread ready in <code>{@thread["cwd"]}</code></p>
        <p class="muted">The {(@spec && @spec.name) || @thread["provider"]} process starts with your first message.</p>
      </div>
      <div :for={item <- @s.items} class="titem" id={"item-" <> item["id"]}><.timeline_item item={item} /></div>
      <div :if={@busy} class="titem working"><span class="spinner"></span> {status_text(@s.status)}…</div>
    </section>

    <footer class="composer">
      <form phx-submit="send" id="composer-form">
        <textarea
          id="composer"
          name="text"
          rows="3"
          phx-hook="Composer"
          placeholder={
            if @busy,
              do: "Queue a follow-up… (⌘↵ to steer the running turn)",
              else: "Message the agent… (↵ to send, ⇧↵ for newline)"
          }
        ></textarea>
        <div class="composer-bar">
          <span class="muted small">
            {status_text(@s.status)}
            <span :if={@s.queued > 0}>· {@s.queued} queued</span>
            <span :if={@s.live_model}>· {@s.live_model}</span>
          </span>
          <span class="row">
            <button :if={@busy} type="button" class="btn" phx-click="interrupt">■ Stop</button>
            <button
              :if={@busy && @spec && Providers.supports?(@spec, :steer)}
              type="submit"
              name="mode"
              value="steer"
              class="btn"
            >Steer</button>
            <button type="submit" name="mode" value="send" class="btn btn-primary">{if @busy, do: "Queue", else: "Send"}</button>
          </span>
        </div>
      </form>
    </footer>
    """
  end

  defp render_panel(%{panel: "diff"} = assigns) do
    ~H"""
    <div class="panel-head">
      <b>Changes</b>
      <span class="muted small">vs {String.slice(@thread["base_sha"] || "HEAD", 0, 7)}</span>
      <button class="mini" phx-click="refresh_diff" title="Refresh">↻</button>
      <button class="mini" phx-click="panel" phx-value-name="diff">×</button>
    </div>
    <div class="panel-body">
      <%= cond do %>
        <% @diff == nil -> %>
          <div class="muted pad">Loading…</div>
        <% @diff == :not_git -> %>
          <div class="muted pad">This project is not a git repository.</div>
        <% @diff == [] -> %>
          <div class="muted pad">No changes yet.</div>
        <% true -> %>
          <div class="muted small pad">
            {elem(diff_totals(@diff), 0)} files · <span class="add">+{elem(diff_totals(@diff), 1)}</span>
            <span class="del">−{elem(diff_totals(@diff), 2)}</span>
          </div>
          <.diff_file :for={f <- @diff} file={f} />
      <% end %>
    </div>
    <form :if={is_list(@diff) and @diff != []} phx-submit="commit" class="panel-foot">
      <input name="message" placeholder="Commit message" value={@thread["title"]} />
      <button class="btn">Commit</button>
      <button type="button" class="btn" phx-click="push" disabled={!@thread["branch"]}>Push</button>
    </form>
    """
  end

  defp render_panel(%{panel: "ship"} = assigns) do
    ~H"""
    <div class="panel-head">
      <b>Ship</b>
      <span class="muted small">commit → push → pull request</span>
      <button class="mini" phx-click="panel" phx-value-name="ship">×</button>
    </div>
    <div class="panel-body">
      <%= cond do %>
        <% not Stratta.Git.repo?(@thread["cwd"]) -> %>
          <div class="muted pad">Shipping needs a git repository.</div>
        <% not Stratta.Git.remote?(@thread["cwd"]) -> %>
          <div class="muted pad">
            No git remote configured. Add one (e.g. <code>gh repo create</code>) to push and open PRs.
          </div>
        <% not Stratta.Git.gh_available?() -> %>
          <div class="muted pad">Install and sign in to the GitHub CLI (<code>gh auth login</code>) to open PRs.</div>
        <% true -> %>
          <form phx-submit="ship" class="ship-form">
            <label>Title <input name="title" value={@pr_draft && @pr_draft["title"]} /></label>
            <label>Body <textarea name="body" rows="14">{@pr_draft && @pr_draft["body"]}</textarea></label>
            <label class="check"><input type="checkbox" name="draft" value="true" /> Open as draft</label>
            <div class="muted small">
              Branch <code>{@thread["branch"]}</code>
              <span :if={@thread["worktree"]}>→ <code>{@thread["base_branch"]}</code></span>
              · {elem(diff_totals(@diff), 0)} changed files
            </div>
            <button class="btn btn-primary">Commit, push & open PR</button>
          </form>
      <% end %>
    </div>
    """
  end

  defp render_panel(assigns), do: ~H""
end
