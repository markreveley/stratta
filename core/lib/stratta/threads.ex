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

    for t <- list_threads() do
      Map.merge(t, %{"status" => Atom.to_string(ThreadServer.status(t["id"])), "project" => names[t["project_id"]]})
    end
  end

  @doc "Finds a thread by id or by a unique id prefix."
  def resolve(ref) when is_binary(ref) and ref != "" do
    threads = list_threads()

    case Enum.find(threads, &(&1["id"] == ref)) || Enum.filter(threads, &String.starts_with?(&1["id"], ref)) do
      %{} = thread -> {:ok, thread}
      [thread] -> {:ok, thread}
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
