defmodule Stratta.API do
  @moduledoc """
  The daemon's command surface: named operations with JSON-shaped arguments
  and results.

  `Stratta.Socket` exposes it to out-of-process clients; anything running in
  the daemon's own node can call it directly. Every operation returns
  `{:ok, result}` or `{:error, message}` and never raises.
  """

  alias Stratta.{Git, Providers, Store, Threads, ThreadServer}

  @approval_modes ~w(default prompt auto_edit auto_approve)

  def version, do: to_string(Application.spec(:stratta, :vsn))

  @spec call(String.t(), map()) :: {:ok, term()} | {:error, String.t()}
  def call(op, args \\ %{}) do
    case run(op, args || %{}) do
      {:ok, _} = ok -> ok
      :ok -> {:ok, %{}}
      {:error, reason} -> {:error, ThreadServer.format_error(reason)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  catch
    :exit, {:timeout, _} -> {:error, "The daemon took too long to answer."}
    :exit, reason -> {:error, "Failed: #{inspect(reason)}"}
  end

  # -- daemon -----------------------------------------------------------------

  defp run("ping", _), do: {:ok, %{"version" => version(), "data_dir" => Store.data_dir(), "pid" => System.pid()}}

  # -- projects & providers ---------------------------------------------------

  defp run("projects.list", _), do: {:ok, Threads.list_projects()}

  defp run("projects.add", %{"path" => path}) do
    with {:ok, project} <- Threads.add_project(path) do
      Threads.broadcast_list()
      {:ok, project}
    end
  end

  defp run("providers.list", args) do
    statuses = Providers.statuses(refresh: args["refresh"] == true)

    {:ok,
     for spec <- Providers.specs() do
       status = statuses[spec.provider]

       %{
         "id" => Atom.to_string(spec.provider),
         "name" => spec.name,
         "ready" => Providers.ready?(status),
         "status" => Providers.label(status),
         "steer" => Providers.supports?(spec, :steer),
         "switch_model" => Providers.can_switch_model?(spec)
       }
     end}
  end

  # -- threads ----------------------------------------------------------------

  defp run("threads.list", _), do: {:ok, Threads.list_with_status()}

  defp run("threads.create", args) do
    provider = args["provider"] || "demo"

    with {:ok, project} <- project_for(args["project"]),
         {:ok, spec} <- provider_spec(provider),
         :ok <- check_option(spec, :approval_mode, args["approval_mode"], @approval_modes),
         {:ok, thread} <- Threads.create_thread(project, Map.put(args, "provider", provider)) do
      message = String.trim(args["message"] || "")

      if message != "" do
        Task.Supervisor.start_child(Stratta.TaskSupervisor, fn -> ThreadServer.send_input(thread["id"], message) end)
      end

      {:ok, thread}
    end
  end

  defp run("thread.get", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]), do: {:ok, ThreadServer.snapshot(thread["id"])}
  end

  defp run("thread.send", %{"text" => text} = args) do
    mode = if args["mode"] == "steer", do: :steer, else: :auto

    with {:ok, thread} <- Threads.resolve(args["thread"]),
         :ok <- if(String.trim(text) == "", do: {:error, "Nothing to send."}, else: :ok),
         {:ok, how} <- ThreadServer.send_input(thread["id"], text, mode) do
      {:ok, %{"how" => Atom.to_string(how), "thread" => thread["id"]}}
    end
  end

  defp run("thread.interrupt", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]) do
      case ThreadServer.interrupt(thread["id"]) do
        {:error, :no_session} -> {:error, "This thread has no running session."}
        other -> other
      end
    end
  end

  defp run("thread.approve", args) do
    decision = if args["decision"] == "deny", do: :deny, else: :approve

    with {:ok, thread} <- Threads.resolve(args["thread"]),
         {:ok, request_id} <- pending_request(thread["id"], args["request_id"]),
         :ok <- ThreadServer.respond_approval(thread["id"], request_id, decision) do
      {:ok, %{"request_id" => request_id, "decision" => Atom.to_string(decision)}}
    end
  end

  defp run("thread.set_model", %{"model" => model} = args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]), do: ThreadServer.set_model(thread["id"], model)
  end

  defp run("thread.diff", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]),
         :ok <- git_repo(thread) do
      base = thread["base_sha"] || "HEAD"
      text = Git.diff_text(thread["cwd"], base)

      files =
        for f <- Git.parse_diff(text) do
          %{
            "path" => f.path,
            "status" => Atom.to_string(f.status),
            "additions" => f.additions,
            "deletions" => f.deletions
          }
        end

      {:ok, %{"text" => text, "files" => files, "base" => base, "cwd" => thread["cwd"]}}
    end
  end

  defp run("thread.commit", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]),
         :ok <- git_repo(thread),
         {:ok, out} <- Threads.commit(thread, blank(args["message"]) || thread["title"]) do
      {:ok, %{"output" => out}}
    end
  end

  defp run("thread.push", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]),
         :ok <- git_repo(thread),
         :ok <- git_remote(thread),
         {:ok, out} <- Threads.push(thread) do
      {:ok, %{"output" => out}}
    end
  end

  defp run("thread.draft_pr", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]),
         :ok <- git_repo(thread) do
      {:ok, Threads.draft_pr(thread, ThreadServer.snapshot(thread["id"]).items)}
    end
  end

  defp run("thread.ship", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]),
         :ok <- git_repo(thread),
         :ok <- git_remote(thread),
         :ok <- if(Git.gh_available?(), do: :ok, else: {:error, "Opening a PR needs the GitHub CLI (gh)."}) do
      draft = Threads.draft_pr(thread, ThreadServer.snapshot(thread["id"]).items)

      attrs = %{
        "title" => blank(args["title"]) || draft["title"],
        "body" => blank(args["body"]) || draft["body"],
        "draft" => args["draft"] == true
      }

      with {:ok, url} <- Threads.ship(thread, attrs), do: {:ok, %{"url" => url}}
    end
  end

  defp run("thread.handoff", %{"provider" => provider} = args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]),
         {:ok, _spec} <- provider_spec(provider) do
      Threads.handoff(thread, provider)
    end
  end

  defp run("thread.delete", args) do
    with {:ok, thread} <- Threads.resolve(args["thread"]) do
      Threads.delete_thread(thread["id"])
      {:ok, %{"deleted" => thread["id"]}}
    end
  end

  defp run(op, _args), do: {:error, "Unknown or incomplete operation: #{op}"}

  # -- helpers ----------------------------------------------------------------

  # A project reference is an id, a name, or a folder path (added on the fly).
  defp project_for(ref) do
    case Threads.resolve_project(ref) do
      {:ok, project} ->
        {:ok, project}

      {:error, _} when is_binary(ref) and ref != "" ->
        with {:ok, project} <- Threads.add_project(ref) do
          Threads.broadcast_list()
          {:ok, project}
        end

      error ->
        error
    end
  end

  defp provider_spec(provider) do
    case Providers.spec(provider) do
      nil ->
        {:error, "Unknown agent #{inspect(provider)}. Known: #{Enum.map_join(Providers.specs(), ", ", & &1.provider)}."}

      spec ->
        {:ok, spec}
    end
  end

  defp check_option(_spec, _field, value, _defaults) when value in [nil, ""], do: :ok

  defp check_option(spec, field, value, defaults) do
    allowed = Enum.map(Providers.allowed_values(spec, field) || defaults, &to_string/1)
    if value in allowed, do: :ok, else: {:error, "#{field} must be one of: #{Enum.join(allowed, ", ")}."}
  end

  defp pending_request(thread_id, wanted) do
    pending =
      for %{"kind" => "approval", "status" => "pending", "request_id" => id} <- ThreadServer.snapshot(thread_id).items,
          do: id

    cond do
      pending == [] -> {:error, "Nothing is waiting for approval in this thread."}
      wanted in [nil, ""] -> {:ok, hd(pending)}
      wanted in pending -> {:ok, wanted}
      true -> {:error, "That approval request is no longer pending."}
    end
  end

  defp git_repo(thread),
    do: if(Git.repo?(thread["cwd"]), do: :ok, else: {:error, "This thread's project is not a git repository."})

  defp git_remote(thread),
    do: if(Git.remote?(thread["cwd"]), do: :ok, else: {:error, "This repository has no git remote to push to."})

  defp blank(v) when v in [nil, ""], do: nil
  defp blank(v), do: v
end
