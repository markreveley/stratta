defmodule Stratta.TUI.CLI do
  @moduledoc """
  The `stratta` command: a client for a running Stratta daemon.

  Exit status: 0 success, 1 the daemon refused or failed, 2 bad usage,
  4 no daemon reachable.
  """

  alias Stratta.TUI.{App, Client, Dashboard, DiffView, Open, Render, Term, Viewer}

  @usage """
  stratta: drive coding-agent threads from the terminal.

  Views
    stratta watch                      Dashboard: every thread, what is waiting on you,
                                       and the current thread's activity
    stratta attach [THREAD]            Live view of one thread: read, reply, approve, steer
    stratta diff [THREAD] [--watch]    The thread's changes against its base commit
    stratta open [THREAD]              Open a thread with $STRATTA_OPENER (else attach here)

  Threads
    stratta ls                         List threads; * marks the current one
    stratta use [THREAD]               Make a thread current, or show which one is
    stratta new [PROMPT...]            Start a thread in the current folder's project
        -a, --agent NAME                 which agent (default: demo; see `stratta agents`)
        -p, --project PATH|NAME          project (default: the current folder)
        --model NAME                     session options, where the agent supports them
        --approval MODE  --sandbox MODE
        --no-worktree                    work in the project folder, not a new branch + worktree
        --attach | --open                view it right away
    stratta send [THREAD] TEXT...      Send a message (queued if a turn is running)
        --steer                          inject into the running turn instead
        -t, --thread THREAD              name the thread explicitly
    stratta approve [REQUEST]          Approve a permission request, e.g. `stratta approve 2a`
    stratta deny [REQUEST]             Deny it
    stratta stop [THREAD]              Interrupt the running turn
    stratta status [THREAD]            One thread's state
    stratta model THREAD NAME          Switch model mid-thread
    stratta handoff THREAD AGENT       Continue in a new thread with another agent
    stratta slot THREAD NUMBER         Move a thread to a slot (swaps with whoever is there)
    stratta unslot THREAD              Free its slot; the thread stays, reachable by id
    stratta rm THREAD                  Delete a thread (and its worktree)

  Git
    stratta commit [THREAD] [-m MSG]   Commit everything in the thread's working folder
    stratta push [THREAD]              Push its branch
    stratta ship [THREAD]              Commit, push and open a pull request
        --title T  --body B  --draft

  Setup
    stratta agents [--refresh]         Agents and whether each is ready
    stratta projects                   Known projects
    stratta project add PATH           Add one

  THREAD is a slot number (the # column of `stratta ls`), a thread id, or a
  unique prefix of an id. Left out, it means the current thread: the one last
  chosen with `stratta use` or started with `stratta new`. $STRATTA_THREAD
  overrides that for one shell.

  REQUEST is a slot number and a letter, as shown wherever a request is
  waiting: 2a is request a of the thread in slot 2. Letters are never reused
  within a thread. A bare slot number works when that thread has exactly one
  request waiting.

  For `send`, a leading number is read as a slot. Use -t to send text that
  starts with a number to the current thread. Put `--` before text that
  starts with a dash. Most commands take --json.

  The current thread is kept per workspace ($STRATTA_WORKSPACE, one shared
  workspace by default), so separate terminal setups can each have their own.

  The daemon is the Stratta core: run `mix run --no-halt` in core/, or start
  the GUI, which serves the same socket ($STRATTA_SOCKET, default ~/.stratta/stratta.sock).
  """

  @switches [
    json: :boolean,
    help: :boolean,
    agent: :string,
    project: :string,
    model: :string,
    approval: :string,
    sandbox: :string,
    worktree: :boolean,
    attach: :boolean,
    open: :boolean,
    steer: :boolean,
    watch: :boolean,
    bell: :boolean,
    refresh: :boolean,
    message: :string,
    title: :string,
    body: :string,
    draft: :boolean,
    thread: :string
  ]

  def main(argv) do
    code =
      try do
        run(argv)
      rescue
        ErlangError -> 0
      end

    System.halt(code)
  end

  @doc "Runs one command and returns its exit status."
  def run(argv) do
    case OptionParser.parse(argv,
           strict: @switches,
           aliases: [a: :agent, p: :project, m: :message, t: :thread, h: :help]
         ) do
      {_opts, _args, [{flag, _} | _]} ->
        fail(2, "Unknown or malformed option #{flag}. Try `stratta help`.")

      {opts, args, []} ->
        cond do
          opts[:help] || args in [[], ["help"]] ->
            IO.write(@usage)
            0

          true ->
            dispatch(args, opts)
        end
    end
  end

  defp dispatch(["ls"], opts) do
    daemon(fn sock ->
      with {:ok, threads} <- Client.call(sock, "threads.list") do
        current = current_id(sock)

        output(opts, threads, fn ->
          table(
            ["", "#", "STATUS", "AGENT", "PROJECT", "TITLE", "ID"],
            for t <- threads do
              waiting = Enum.map_join(t["pending"] || [], " ", &"#{t["slot"]}#{&1["label"]}")
              status = String.trim("#{status_label(t["status"])} #{waiting}")

              [
                if(t["id"] == current, do: "*", else: ""),
                t["slot"] || "-",
                status,
                t["provider"],
                t["project"],
                t["title"],
                t["id"]
              ]
            end
          )
        end)
      end
    end)
  end

  defp dispatch(["agents"], opts) do
    daemon(fn sock ->
      with {:ok, agents} <- Client.call(sock, "providers.list", %{"refresh" => opts[:refresh] == true}) do
        output(opts, agents, fn ->
          table(["AGENT", "NAME", "STATUS"], for(a <- agents, do: [a["id"], a["name"], a["status"]]))
        end)
      end
    end)
  end

  defp dispatch(["projects"], opts) do
    daemon(fn sock ->
      with {:ok, projects} <- Client.call(sock, "projects.list") do
        output(opts, projects, fn ->
          table(["ID", "NAME", "PATH"], for(p <- projects, do: [p["id"], p["name"], p["path"]]))
        end)
      end
    end)
  end

  defp dispatch(["project", "add", path], opts) do
    daemon(fn sock ->
      with {:ok, project} <- Client.call(sock, "projects.add", %{"path" => Path.expand(path)}) do
        output(opts, project, fn -> IO.puts("#{project["id"]}  #{project["path"]}") end)
      end
    end)
  end

  defp dispatch(["new" | prompt], opts) do
    args = %{
      "project" => (opts[:project] && expand_if_path(opts[:project])) || File.cwd!(),
      "provider" => opts[:agent] || "demo",
      "worktree" => Keyword.get(opts, :worktree, true),
      "model" => opts[:model],
      "approval_mode" => opts[:approval],
      "sandbox_mode" => opts[:sandbox],
      "message" => Enum.join(prompt, " "),
      "workspace" => workspace()
    }

    daemon(fn sock ->
      with {:ok, thread} <- Client.call(sock, "threads.create", args) do
        cond do
          opts[:attach] -> attach(thread["id"], opts)
          opts[:open] -> open(sock, thread["id"], opts)
          true -> output(opts, thread, fn -> IO.puts("Thread #{tag(thread)} · #{thread["id"]}") end)
        end
      end
    end)
  end

  defp dispatch(["use"], opts) do
    daemon(fn sock ->
      with {:ok, result} <- Client.call(sock, "current.get", %{"workspace" => workspace()}) do
        output(opts, result, fn ->
          case result["thread"] do
            nil -> IO.puts("No current thread. Choose one with `stratta use N`.")
            thread -> IO.puts("On thread #{tag(thread)} · #{thread["title"]}")
          end
        end)
      end
    end)
  end

  defp dispatch(["use", ref], opts) do
    simple(opts, "current.set", %{"thread" => ref, "workspace" => workspace()}, fn thread ->
      "Now on thread #{tag(thread)} · #{thread["title"]}"
    end)
  end

  defp dispatch(["slot", ref, number], opts) do
    case Integer.parse(number) do
      {slot, ""} ->
        simple(opts, "thread.slot", %{"thread" => ref, "slot" => slot}, fn thread ->
          "#{thread["title"]} is now in slot #{thread["slot"]}."
        end)

      _ ->
        fail(2, "Usage: stratta slot THREAD NUMBER")
    end
  end

  defp dispatch(["unslot", ref], opts) do
    simple(opts, "thread.slot", %{"thread" => ref, "slot" => nil}, fn thread ->
      "#{thread["title"]} left its slot. It is still reachable as #{thread["id"]}."
    end)
  end

  defp dispatch(["attach" | rest], opts), do: with_thread(rest, fn _sock, ref, [] -> attach(ref, opts) end)
  defp dispatch(["open" | rest], opts), do: with_thread(rest, fn sock, ref, [] -> open(sock, ref, opts) end)

  defp dispatch(["watch"], opts) do
    if Term.tty?(), do: daemon(&watch(&1, opts)), else: fail(2, "watch needs a terminal.")
  end

  defp dispatch(["diff" | rest], opts) do
    with_thread(rest, fn sock, ref, [] ->
      cond do
        opts[:watch] && Term.tty?() ->
          view(DiffView, sock, %{thread: ref})

        opts[:watch] ->
          fail(2, "diff --watch needs a terminal.")

        true ->
          with {:ok, diff} <- Client.call(sock, "thread.diff", %{"thread" => ref}) do
            output(opts, diff, fn -> print_diff(diff) end)
          end
      end
    end)
  end

  defp dispatch(["send" | words], opts) do
    mode = if opts[:steer], do: "steer", else: "auto"

    daemon(fn sock ->
      with {:ok, ref, text} <- send_target(sock, words, opts),
           {:ok, result} <-
             Client.call(sock, "thread.send", %{"thread" => ref, "text" => Enum.join(text, " "), "mode" => mode}) do
        output(opts, result, fn -> IO.puts(how(result["how"])) end)
      end
    end)
  end

  defp dispatch([verb | rest], opts) when verb in ["approve", "deny"] do
    daemon(fn sock ->
      target =
        case rest do
          [] ->
            with {:ok, ref} <- default_thread(sock), do: {:ok, %{"thread" => ref}}

          [ref] ->
            {:ok, %{"thread" => ref}}

          [ref, label] ->
            {:ok, %{"thread" => ref, "label" => label}}

          _ ->
            {:usage,
             "Usage: stratta #{verb} [REQUEST], where REQUEST is like 2a, or a thread with one request waiting."}
        end

      with {:ok, args} <- target,
           {:ok, result} <- Client.call(sock, "thread.approve", Map.put(args, "decision", verb)) do
        output(opts, result, fn ->
          IO.puts("#{if(verb == "approve", do: "Approved", else: "Denied")} #{result["label"]}: #{result["title"]}")
        end)
      end
    end)
  end

  defp dispatch(["stop" | rest], opts) do
    with_thread(rest, fn sock, ref, [] ->
      with {:ok, result} <- Client.call(sock, "thread.interrupt", %{"thread" => ref}) do
        output(opts, result, fn -> IO.puts("Interrupted.") end)
      end
    end)
  end

  defp dispatch(["status" | rest], opts) do
    with_thread(rest, fn sock, ref, [] ->
      with {:ok, snapshot} <- Client.call(sock, "thread.get", %{"thread" => ref}) do
        output(opts, snapshot, fn -> print_status(snapshot) end)
      end
    end)
  end

  defp dispatch(["model", ref, model], opts) do
    simple(opts, "thread.set_model", %{"thread" => ref, "model" => model}, fn _ -> "Model set to #{model}." end)
  end

  defp dispatch(["handoff", ref, agent], opts) do
    simple(opts, "thread.handoff", %{"thread" => ref, "provider" => agent, "workspace" => workspace()}, fn thread ->
      "Thread #{tag(thread)} · #{thread["id"]}"
    end)
  end

  defp dispatch(["rm", ref], opts) do
    simple(opts, "thread.delete", %{"thread" => ref}, fn result -> "Deleted #{result["deleted"]}." end)
  end

  defp dispatch(["commit" | rest], opts) do
    with_thread(rest, fn sock, ref, [] ->
      with {:ok, result} <- Client.call(sock, "thread.commit", %{"thread" => ref, "message" => opts[:message]}) do
        output(opts, result, fn -> IO.puts(result["output"]) end)
      end
    end)
  end

  defp dispatch(["push" | rest], opts) do
    with_thread(rest, fn sock, ref, [] ->
      with {:ok, result} <- Client.call(sock, "thread.push", %{"thread" => ref}) do
        output(opts, result, fn -> IO.puts(result["output"]) end)
      end
    end)
  end

  defp dispatch(["ship" | rest], opts) do
    with_thread(rest, fn sock, ref, [] ->
      args = %{"thread" => ref, "title" => opts[:title], "body" => opts[:body], "draft" => opts[:draft] == true}

      with {:ok, result} <- Client.call(sock, "thread.ship", args) do
        output(opts, result, fn -> IO.puts(result["url"]) end)
      end
    end)
  end

  defp dispatch([command | _], _opts),
    do: fail(2, "Unknown command or wrong arguments: #{command}. Try `stratta help`.")

  defp attach(ref, opts) do
    if Term.tty?() do
      daemon(fn sock -> view(Viewer, sock, %{thread: ref, bell: opts[:bell] == true}) end)
    else
      fail(2, "attach needs a terminal.")
    end
  end

  defp open(sock, ref, opts) do
    with {:ok, snapshot} <- Client.call(sock, "thread.get", %{"thread" => ref}) do
      case Open.run(snapshot["thread"]) do
        :ok -> 0
        :inline -> attach(snapshot["thread"]["id"], opts)
        {:error, _} = error -> error
      end
    end
  end

  defp watch(sock, opts) do
    case App.run(Dashboard, sock, %{workspace: workspace()}) do
      {:open, id} ->
        case open(sock, id, opts) do
          {:error, message} -> fail(1, message)
          _ -> watch(sock, opts)
        end

      other ->
        view_result(other)
    end
  end

  defp view(module, sock, arg), do: module |> App.run(sock, arg) |> view_result()

  defp view_result({:error, _} = error), do: error
  defp view_result(_done), do: 0

  defp daemon(fun) do
    case Client.connect() do
      {:ok, sock} ->
        try do
          case fun.(sock) do
            code when is_integer(code) -> code
            :ok -> 0
            {:ok, _} -> 0
            {:usage, message} -> fail(2, message)
            {:error, message} -> fail(1, message)
          end
        after
          :gen_tcp.close(sock)
        end

      {:error, _reason} ->
        fail(4, """
        No Stratta daemon is running (no answer at #{Client.socket_path()}).
        Start one with `mix run --no-halt` in core/, or start the GUI.\
        """)
    end
  end

  defp simple(opts, op, args, line) do
    daemon(fn sock ->
      with {:ok, result} <- Client.call(sock, op, args) do
        output(opts, result, fn -> IO.puts(line.(result)) end)
      end
    end)
  end

  defp with_thread(args, fun) do
    daemon(fn sock ->
      case args do
        [ref | rest] ->
          fun.(sock, ref, rest)

        [] ->
          with {:ok, ref} <- default_thread(sock), do: fun.(sock, ref, [])
      end
    end)
  rescue
    FunctionClauseError -> fail(2, "Too many arguments. Try `stratta help`.")
  end

  defp default_thread(sock) do
    case System.get_env("STRATTA_THREAD") do
      ref when ref not in [nil, ""] ->
        {:ok, ref}

      _ ->
        case current_id(sock) || Client.call(sock, "threads.list") do
          id when is_binary(id) ->
            {:ok, id}

          {:ok, [only]} ->
            {:ok, only["id"]}

          {:ok, []} ->
            {:usage, "There are no threads yet. Start one with `stratta new`."}

          {:ok, _many} ->
            {:usage, "Which thread? Pass its number (see `stratta ls`) or choose one with `stratta use N`."}

          error ->
            error
        end
    end
  end

  defp current_id(sock) do
    case Client.call(sock, "current.get", %{"workspace" => workspace()}) do
      {:ok, %{"thread" => %{"id" => id}}} -> id
      _ -> nil
    end
  end

  defp send_target(_sock, [], _opts), do: {:usage, "Usage: stratta send [THREAD] TEXT..."}

  defp send_target(sock, [first | rest] = words, opts) do
    env = System.get_env("STRATTA_THREAD")

    cond do
      opts[:thread] -> {:ok, opts[:thread], words}
      env not in [nil, ""] -> {:ok, env, words}
      rest != [] and first =~ ~r/^\d+$/ -> {:ok, first, rest}
      rest != [] and thread_id?(sock, first) -> {:ok, first, rest}
      true -> with {:ok, ref} <- default_thread(sock), do: {:ok, ref, words}
    end
  end

  defp thread_id?(sock, word) do
    word =~ ~r/^t[\w-]{8}$/ and
      match?(
        {:ok, [_ | _]},
        with({:ok, threads} <- Client.call(sock, "threads.list"), do: {:ok, Enum.filter(threads, &(&1["id"] == word))})
      )
  end

  defp workspace do
    case System.get_env("STRATTA_WORKSPACE") do
      name when name in [nil, ""] -> "default"
      name -> name
    end
  end

  defp tag(thread), do: to_string(thread["slot"] || thread["id"])

  defp expand_if_path(ref), do: if(String.contains?(ref, "/") or ref in [".", ".."], do: Path.expand(ref), else: ref)

  defp output(opts, data, human) do
    if opts[:json], do: IO.puts(Jason.encode!(data)), else: human.()
    0
  end

  defp fail(code, message) do
    IO.puts(:stderr, message)
    code
  end

  defp how("sent"), do: "Sent."
  defp how("queued"), do: "Queued behind the running turn."
  defp how("steer"), do: "Steered the running turn."
  defp how(other), do: to_string(other)

  defp status_label("awaiting_approval"), do: "needs approval"
  defp status_label("detached"), do: "not running"
  defp status_label(other), do: to_string(other)

  defp print_status(snapshot) do
    thread = snapshot["thread"]
    items = snapshot["items"] || []

    waiting =
      for %{"kind" => "approval", "status" => "pending"} = i <- items,
          do: "#{thread["slot"]}#{i["label"]} #{i["title"]}"

    last = items |> Enum.filter(&(&1["kind"] == "assistant")) |> List.last()

    rows =
      [
        {"thread", "#{thread["slot"] || "-"} · #{thread["title"]}  (#{thread["id"]})"},
        {"status", status_label(snapshot["status"])},
        {"agent",
         [thread["provider"], snapshot["live_model"] || thread["model"]] |> Enum.filter(& &1) |> Enum.join(" · ")},
        {"branch", thread["branch"]},
        {"folder", thread["cwd"]},
        {"pull request", thread["pr_url"]},
        {"waiting on", Enum.join(waiting, "; ")},
        {"last reply", last && last["text"] |> String.split("\n") |> hd() |> Render.fit(100)}
      ]

    for {label, value} <- rows, value not in [nil, "", false] do
      IO.puts(String.pad_trailing(label, 13) <> value)
    end
  end

  defp print_diff(%{"files" => []}), do: IO.puts("No changes.")

  defp print_diff(%{"text" => text}) do
    if IO.ANSI.enabled?() do
      for line <- Render.unified_diff(text, 100_000), do: IO.puts(Render.ansi(line, 100_000))
    else
      IO.write(text)
    end
  end

  defp table(_header, []), do: IO.puts("(none)")

  defp table(header, rows) do
    rows = [header | Enum.map(rows, fn row -> Enum.map(row, &to_string(&1 || "")) end)]
    last = length(header) - 1

    widths =
      for index <- 0..last do
        rows |> Enum.map(&String.length(Enum.at(&1, index))) |> Enum.max()
      end

    for row <- rows do
      row
      |> Enum.with_index()
      |> Enum.map_join("  ", fn {cell, index} ->
        if index == last, do: cell, else: String.pad_trailing(cell, Enum.at(widths, index))
      end)
      |> IO.puts()
    end
  end
end
