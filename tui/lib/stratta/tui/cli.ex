defmodule Stratta.TUI.CLI do
  @moduledoc """
  The `stratta` command: a client for a running Stratta daemon.

  Exit status: 0 success, 1 the daemon refused or failed, 2 bad usage,
  4 no daemon reachable.
  """

  alias Stratta.TUI.{App, Client, DiffView, Open, Render, Term, Viewer, Watch}

  @usage """
  stratta: drive coding-agent threads from the terminal.

  Views
    stratta attach [THREAD]            Live view of one thread: read, reply, approve, steer
    stratta watch                      Every thread and its status; enter opens one
    stratta diff [THREAD] [--watch]    The thread's changes against its base commit
    stratta open [THREAD]              Open a thread with $STRATTA_OPENER (else attach here)

  Threads
    stratta ls                         List threads
    stratta new [PROMPT...]            Start a thread in the current folder's project
        -a, --agent NAME                 which agent (default: demo; see `stratta agents`)
        -p, --project PATH|NAME          project (default: the current folder)
        --model NAME                     session options, where the agent supports them
        --approval MODE  --sandbox MODE
        --no-worktree                    work in the project folder, not a new branch + worktree
        --attach | --open                view it right away
    stratta send THREAD TEXT...        Send a message (queued if a turn is running)
        --steer                          inject into the running turn instead
    stratta approve [THREAD]           Approve the pending permission request
    stratta deny [THREAD]              Deny it
    stratta stop [THREAD]              Interrupt the running turn
    stratta status [THREAD]            One thread's state
    stratta model THREAD NAME          Switch model mid-thread
    stratta handoff THREAD AGENT       Continue in a new thread with another agent
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

  THREAD is a thread id or any unique prefix of one. Where it is optional it
  defaults to $STRATTA_THREAD, or to the only thread if there is just one.
  Most commands take --json. Put `--` before text that starts with a dash.

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
    draft: :boolean
  ]

  def main(argv) do
    code =
      try do
        run(argv)
      rescue
        # Output closed under us, as in `stratta ls | head -1`.
        ErlangError -> 0
      end

    System.halt(code)
  end

  @doc "Runs one command and returns its exit status."
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches, aliases: [a: :agent, p: :project, m: :message, h: :help]) do
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

  # -- commands ---------------------------------------------------------------

  defp dispatch(["ls"], opts) do
    daemon(fn sock ->
      with {:ok, threads} <- Client.call(sock, "threads.list") do
        output(opts, threads, fn ->
          table(
            ["ID", "STATUS", "AGENT", "PROJECT", "TITLE"],
            for(t <- threads, do: [t["id"], status_label(t["status"]), t["provider"], t["project"], t["title"]])
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
      "message" => Enum.join(prompt, " ")
    }

    daemon(fn sock ->
      with {:ok, thread} <- Client.call(sock, "threads.create", args) do
        cond do
          opts[:attach] -> attach(thread["id"], opts)
          opts[:open] -> open(sock, thread["id"], opts)
          true -> output(opts, thread, fn -> IO.puts(thread["id"]) end)
        end
      end
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

  defp dispatch(["send" | rest], opts) do
    # With $STRATTA_THREAD set, every argument is text.
    {ref, text} =
      case {System.get_env("STRATTA_THREAD"), rest} do
        {env, words} when env not in [nil, ""] -> {env, words}
        {_, [ref | words]} -> {ref, words}
        {_, []} -> {nil, []}
      end

    if ref == nil or text == [] do
      fail(2, "Usage: stratta send THREAD TEXT...")
    else
      args = %{"thread" => ref, "text" => Enum.join(text, " "), "mode" => if(opts[:steer], do: "steer", else: "auto")}

      daemon(fn sock ->
        with {:ok, result} <- Client.call(sock, "thread.send", args) do
          output(opts, result, fn -> IO.puts(how(result["how"])) end)
        end
      end)
    end
  end

  defp dispatch([verb | rest], opts) when verb in ["approve", "deny"] do
    with_thread(rest, fn sock, ref, [] ->
      with {:ok, result} <- Client.call(sock, "thread.approve", %{"thread" => ref, "decision" => verb}) do
        output(opts, result, fn -> IO.puts(if(verb == "approve", do: "Approved.", else: "Denied.")) end)
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
    simple(opts, "thread.handoff", %{"thread" => ref, "provider" => agent}, fn thread -> thread["id"] end)
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

  # -- views ------------------------------------------------------------------

  # A view gets its own connection, so its subscription ends with it.
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
    case App.run(Watch, sock, nil) do
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

  # -- plumbing ---------------------------------------------------------------

  defp daemon(fun) do
    case Client.connect() do
      {:ok, sock} ->
        try do
          case fun.(sock) do
            code when is_integer(code) -> code
            :ok -> 0
            {:ok, _} -> 0
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

  # Resolves the optional leading THREAD argument and passes on the rest.
  defp with_thread(args, fun) do
    daemon(fn sock ->
      case args do
        [ref | rest] ->
          fun.(sock, ref, rest)

        [] ->
          case default_thread(sock) do
            {:ok, ref} -> fun.(sock, ref, [])
            {:error, message} -> fail(2, message)
          end
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
        case Client.call(sock, "threads.list") do
          {:ok, [only]} -> {:ok, only["id"]}
          {:ok, []} -> {:error, "There are no threads yet. Start one with `stratta new`."}
          {:ok, _many} -> {:error, "Which thread? Pass an id (see `stratta ls`) or set STRATTA_THREAD."}
          error -> error
        end
    end
  end

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
    approval = Stratta.TUI.Status.pending_approval(items)
    last = items |> Enum.filter(&(&1["kind"] == "assistant")) |> List.last()

    rows =
      [
        {"thread", "#{thread["id"]}  #{thread["title"]}"},
        {"status", status_label(snapshot["status"])},
        {"agent",
         [thread["provider"], snapshot["live_model"] || thread["model"]] |> Enum.filter(& &1) |> Enum.join(" · ")},
        {"branch", thread["branch"]},
        {"folder", thread["cwd"]},
        {"pull request", thread["pr_url"]},
        {"waiting on", approval && approval["title"]},
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
