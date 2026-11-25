defmodule Stratta.Threads do
  @moduledoc "Projects and threads: the public API the LiveViews use."

  alias Stratta.{Git, Store, ThreadServer}

  # -- projects ---------------------------------------------------------------

  def list_projects, do: Store.list_projects()
  def get_project(id), do: Store.get_project(id)

  def add_project(path) do
    path = path |> String.trim() |> Path.expand()

    cond do
      path == "" ->
        {:error, "Enter a folder path."}

      not File.dir?(path) ->
        {:error, "#{path} is not a folder."}

      true ->
        root =
          case Git.toplevel(path) do
            {:ok, top} -> top
            _ -> path
          end

        case Enum.find(Store.list_projects(), &(&1["path"] == root)) do
          nil ->
            Store.put_project(%{
              "id" => id("p"),
              "name" => Path.basename(root),
              "path" => root,
              "git" => Git.repo?(root),
              "created_at" => now()
            })

          existing ->
            {:ok, existing}
        end
    end
  end

  def remove_project(id) do
    for t <- list_threads(), t["project_id"] == id, do: delete_thread(t["id"])
    Store.delete_project(id)
  end

  # -- threads ----------------------------------------------------------------

  def list_threads, do: Store.list_threads()
  def get_thread(id), do: Store.get_thread(id)

  @doc "Threads with their live `status` and their project's name, newest first."
  def list_with_status do
    names = Map.new(list_projects(), &{&1["id"], &1["name"]})

    threads =
      for t <- list_threads() do
        summary = ThreadServer.summary(t["id"])

        Map.merge(t, %{
          "status" => Atom.to_string(summary.status),
          "pending" => summary.pending,
          "project" => names[t["project_id"]]
        })
      end

    # Slotted threads first, in slot order; list_threads/0 already put the rest newest first.
    {slotted, unslotted} = Enum.split_with(threads, & &1["slot"])
    Enum.sort_by(slotted, & &1["slot"]) ++ unslotted
  end

  # -- slots ------------------------------------------------------------------
  #
  # A slot is a small number a thread sits in, so people can say `2` instead
  # of an id. A new thread takes the lowest free slot. Slots never shift on
  # their own: one changes hands only when its thread is deleted, unslotted
  # or moved.

  @max_slot 99

  @doc "The lowest slot no thread is sitting in."
  def next_slot do
    taken = MapSet.new(list_threads(), & &1["slot"])
    Enum.find(1..@max_slot, &(not MapSet.member?(taken, &1)))
  end

  @doc "Puts a thread in a slot. A thread already there takes the slot this one leaves."
  def set_slot(%{"id" => id} = thread, slot) when is_integer(slot) and slot in 1..@max_slot do
    case Enum.find(list_threads(), &(&1["slot"] == slot and &1["id"] != id)) do
      nil -> :ok
      occupant -> update_thread(occupant["id"], &Map.put(&1, "slot", thread["slot"]))
    end

    update_thread(id, &Map.put(&1, "slot", slot))
  end

  def set_slot(_thread, _slot), do: {:error, "A slot is a number from 1 to #{@max_slot}."}

  @doc "Takes a thread out of its slot. The thread stays, reachable by its id."
  def clear_slot(%{"id" => id}), do: update_thread(id, &Map.put(&1, "slot", nil))

  @doc "Gives a slot to every thread that has never had one (threads made before slots existed)."
  def ensure_slots do
    list_threads()
    |> Enum.reject(&Map.has_key?(&1, "slot"))
    |> Enum.sort_by(& &1["created_at"])
    |> Enum.each(fn thread -> Store.put_thread(Map.put(thread, "slot", next_slot())) end)
  end

  # A running thread's process holds the authoritative copy of its metadata.
  defp update_thread(id, fun) do
    case Registry.lookup(Stratta.ThreadRegistry, id) do
      [{_pid, _}] ->
        ThreadServer.update_meta(id, fun)

      [] ->
        {:ok, thread} = Store.put_thread(fun.(Store.get_thread(id)))
        broadcast_list()
        {:ok, thread}
    end
  end

  # -- current thread ---------------------------------------------------------
  #
  # Each workspace (a name; one shared "default" unless a client says
  # otherwise) has a current thread: what commands act on when they name no
  # thread, and what a dashboard shows. Changing it in one place is seen by
  # every client watching that workspace.

  def current(workspace) do
    case Store.get_current(workspace) do
      nil -> nil
      id -> Store.get_thread(id)
    end
  end

  def set_current(workspace, thread_id) do
    Store.put_current(workspace, thread_id)
    Phoenix.PubSub.broadcast(Stratta.PubSub, "current", {:current, workspace, thread_id})
    :ok
  end

  @doc "Finds a thread by slot number, by id, or by a unique id prefix."
  def resolve(ref) when is_integer(ref), do: resolve(Integer.to_string(ref))

  def resolve(ref) when is_binary(ref) and ref != "" do
    threads = list_threads()

    by_slot =
      case Integer.parse(ref) do
        {slot, ""} -> Enum.find(threads, &(&1["slot"] == slot)) || []
        _ -> nil
      end

    case by_slot || Enum.find(threads, &(&1["id"] == ref)) || Enum.filter(threads, &String.starts_with?(&1["id"], ref)) do
      %{} = thread -> {:ok, thread}
      [thread] -> {:ok, thread}
      [] when is_list(by_slot) -> {:error, "No thread is in slot #{ref}."}
      [] -> {:error, "No thread matches #{inspect(ref)}."}
      many -> {:error, "#{inspect(ref)} matches #{length(many)} threads; use more of the id."}
    end
  end

  def resolve(_), do: {:error, "No thread given."}

  @doc "Finds a project by id, name or path."
  def resolve_project(ref) when is_binary(ref) and ref != "" do
    expanded = Path.expand(ref)

    case Enum.find(list_projects(), &(ref in [&1["id"], &1["name"]] or &1["path"] == expanded)) do
      nil -> {:error, "No project matches #{inspect(ref)}."}
      project -> {:ok, project}
    end
  end

  def resolve_project(_), do: {:error, "No project given."}

  @doc """
  Creates a thread. With `worktree: true` in a git project, the thread gets
  its own branch `stratta/<slug>` and worktree, so parallel agents never step
  on each other's files.
  """
  def create_thread(project, attrs) do
    thread_id = id("t")
    provider = Map.fetch!(attrs, "provider")
    worktree? = attrs["worktree"] in [true, "true", "on"] and project["git"] and Git.has_commits?(project["path"])
    base_branch = if project["git"], do: Git.current_branch(project["path"])

    {cwd, branch, base_sha} =
      if worktree? do
        branch = "stratta/#{provider}-#{String.slice(thread_id, -6, 6)}"
        base_sha = Git.head_sha(project["path"])

        case Git.create_worktree(project["path"], branch, base_sha) do
          {:ok, dir} -> {dir, branch, base_sha}
          {:error, reason} -> throw({:worktree_failed, reason})
        end
      else
        {project["path"], base_branch, project["git"] && Git.head_sha(project["path"])}
      end

    thread = %{
      "id" => thread_id,
      "slot" => next_slot(),
      "project_id" => project["id"],
      "title" => "New thread",
      "provider" => provider,
      "model" => blank(attrs["model"]),
      "approval_mode" => blank(attrs["approval_mode"]),
      "sandbox_mode" => blank(attrs["sandbox_mode"]),
      "reasoning_effort" => blank(attrs["reasoning_effort"]),
      "system_prompt" => blank(attrs["system_prompt"]),
      "cwd" => cwd,
      "worktree" => worktree?,
      "branch" => branch,
      "base_branch" => base_branch,
      "base_sha" => base_sha,
      "pr_url" => nil,
      "created_at" => now(),
      "updated_at" => now()
    }

    {:ok, thread} = Store.put_thread(thread)
    broadcast_list()
    {:ok, thread}
  catch
    {:worktree_failed, reason} -> {:error, "Could not create worktree: #{reason}"}
  end

  @doc """
  Hands a thread off to another provider: a new thread in the same working
  directory and branch, seeded with a transcript summary of the original.
  """
  def handoff(thread, provider) do
    items = ThreadServer.snapshot(thread["id"]).items

    transcript =
      items
      |> Enum.filter(&(&1["kind"] in ["user", "assistant"]))
      |> Enum.take(-20)
      |> Enum.map_join("\n\n", fn i -> "#{String.upcase(i["kind"])}: #{String.slice(i["text"] || "", 0, 2000)}" end)

    new = %{
      "id" => id("t"),
      "slot" => next_slot(),
      "title" => "#{thread["title"]} → #{provider}",
      "provider" => provider,
      "model" => nil,
      "provider_session_id" => nil,
      "handoff_from" => thread["id"],
      "handoff_context" => transcript,
      "created_at" => now(),
      "updated_at" => now()
    }

    {:ok, new} = Store.put_thread(Map.merge(Map.drop(thread, ["pr_url"]), new))
    broadcast_list()
    {:ok, new}
  end

  def delete_thread(id) do
    case Registry.lookup(Stratta.ThreadRegistry, id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Stratta.ThreadSupervisor, pid)
      [] -> :ok
    end

    with %{"worktree" => true, "cwd" => cwd, "project_id" => pid} <- Store.get_thread(id),
         %{"path" => path} <- Store.get_project(pid),
         false <- Enum.any?(Store.list_threads(), &(&1["id"] != id and &1["cwd"] == cwd)) do
      Git.remove_worktree(path, cwd)
    end

    Store.delete_thread(id)
    for {workspace, ^id} <- Store.all_current(), do: set_current(workspace, nil)
    broadcast_list()
  end

  def broadcast_list, do: Phoenix.PubSub.broadcast(Stratta.PubSub, "threads", :threads_changed)

  # -- git actions ------------------------------------------------------------

  def diff(thread), do: Git.diff(thread["cwd"], thread["base_sha"] || "HEAD")

  def commit(thread, message) do
    result = Git.commit(thread["cwd"], message)
    note(thread, result, "Committed", "Commit failed")
    result
  end

  def push(thread) do
    result = Git.push(thread["cwd"], thread["branch"])
    note(thread, result, "Pushed #{thread["branch"]}", "Push failed")
    result
  end

  @doc "Commit (if dirty), push, and open a PR in one go."
  def ship(thread, %{"title" => title, "body" => body} = attrs) do
    cwd = thread["cwd"]

    with :ok <- if(Git.status(cwd) == [], do: :ok, else: Git.commit(cwd, title) |> ok_or_error()),
         {:ok, _} <- Git.push(cwd, thread["branch"]),
         {:ok, url} <-
           Git.create_pr(cwd, %{
             title: title,
             body: body,
             head: thread["branch"],
             base: if(thread["worktree"], do: thread["base_branch"]),
             draft: attrs["draft"] in [true, "true", "on"]
           }) do
      ThreadServer.update_meta(thread["id"], &Map.put(&1, "pr_url", url))
      ThreadServer.add_notice(thread["id"], :success, "Opened pull request: #{url}")
      {:ok, url}
    else
      {:error, reason} = err ->
        ThreadServer.add_notice(thread["id"], :error, "Ship failed: #{reason}")
        err
    end
  end

  @doc "Draft a PR title/body from the thread transcript (no model call)."
  def draft_pr(thread, items) do
    asks = items |> Enum.filter(&(&1["kind"] == "user")) |> Enum.map(& &1["text"])
    answer = items |> Enum.filter(&(&1["kind"] == "assistant")) |> List.last()
    files = diff(thread) |> Enum.map(&"- `#{&1.path}` (+#{&1.additions} −#{&1.deletions})")

    title = (List.first(asks) || thread["title"] || "Changes") |> String.split("\n") |> hd() |> String.slice(0, 72)

    body = """
    ## Summary
    #{(answer && answer["text"]) || "_No summary from the agent._"}

    ## Requests
    #{Enum.map_join(asks, "\n", &"- #{String.slice(&1, 0, 200)}")}

    ## Changed files
    #{Enum.join(files, "\n")}

    ---
    Made in Stratta with the `#{thread["provider"]}` agent via Jido.Harness.
    """

    %{"title" => title, "body" => String.trim(body)}
  end

  defp ok_or_error({:ok, _}), do: :ok
  defp ok_or_error(err), do: err

  defp note(thread, {:ok, out}, ok, _), do: ThreadServer.add_notice(thread["id"], :success, "#{ok}. #{first_line(out)}")
  defp note(thread, {:error, out}, _, bad), do: ThreadServer.add_notice(thread["id"], :error, "#{bad}: #{out}")

  defp first_line(text), do: text |> String.split("\n") |> hd()

  defp blank(v) when v in [nil, ""], do: nil
  defp blank(v), do: v

  defp id(prefix), do: prefix <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  defp now, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
