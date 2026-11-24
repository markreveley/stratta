defmodule Stratta.TUI.CLITest do
  # Runs the real commands and views against a real daemon (the core, started
  # in this VM) driving the bundled demo agent.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Stratta.TUI.{CLI, Client, Open, Render, Viewer}

  setup do
    dir = Path.join(System.tmp_dir!(), "stratta-cli-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    git = fn args -> {_, 0} = System.cmd("git", args, cd: dir, stderr_to_stdout: true) end
    git.(["init", "-q", "-b", "main"])
    File.write!(Path.join(dir, "README.md"), "# x\n")
    git.(["add", "."])
    git.(["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "-q", "-m", "init"])
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  defp stratta(args) do
    {code, out} = with_io(fn -> CLI.run(args) end)
    {String.trim(out), code}
  end

  defp json(args) do
    {out, 0} = stratta(args ++ ["--json"])
    Jason.decode!(out)
  end

  defp wait_until(fun, tries \\ 150) do
    cond do
      value = fun.() -> value
      tries == 0 -> flunk("timed out")
      true -> Process.sleep(100) && wait_until(fun, tries - 1)
    end
  end

  test "usage errors and help" do
    assert {out, 0} = stratta(["help"])
    assert out =~ "stratta attach"
    assert capture_io(:stderr, fn -> assert CLI.run(["frobnicate"]) == 2 end) =~ "Unknown command"
    assert capture_io(:stderr, fn -> assert CLI.run(["ls", "--nope"]) == 2 end) =~ "--nope"
    assert capture_io(:stderr, fn -> assert CLI.run(["status", "no-such-thread"]) == 1 end) =~ "No thread matches"
  end

  test "reports a missing daemon with its own exit status" do
    real = System.get_env("STRATTA_SOCKET")
    System.put_env("STRATTA_SOCKET", "/nonexistent/stratta.sock")
    on_exit(fn -> System.put_env("STRATTA_SOCKET", real) end)

    try do
      assert capture_io(:stderr, fn -> assert CLI.run(["ls"]) == 4 end) =~ "No Stratta daemon is running"
    after
      System.put_env("STRATTA_SOCKET", real)
    end
  end

  test "new, approve, diff, commit from the command line", %{dir: dir} do
    {id, 0} = stratta(["new", "-p", dir, "create", "a", "file"])

    assert %{"status" => "awaiting_approval"} =
             wait_until(fn -> (s = json(["status", id])) && s["status"] == "awaiting_approval" && s end)

    {listing, 0} = stratta(["ls"])
    assert listing =~ "needs approval"
    assert {"Approved.", 0} = stratta(["approve", id])

    wait_until(fn -> json(["status", id])["status"] == "idle" end)
    assert %{"files" => [%{"path" => "STRATTA_DEMO.md"}]} = json(["diff", id])
    assert {out, 0} = stratta(["commit", id, "-m", "demo"])
    assert out =~ "demo"
    assert capture_io(:stderr, fn -> assert CLI.run(["push", id]) == 1 end) =~ "no git remote"

    assert {"Queued behind the running turn." <> _, 0} =
             stratta(["send", id, "one"]) |> then(fn _ -> stratta(["send", id, "two"]) end)
  end

  test "the viewer follows a thread, answers an approval and reports status", %{dir: dir} do
    {id, 0} = stratta(["new", "-p", dir, "--no-worktree"])
    {:ok, sock} = Client.connect()
    {:ok, st} = Viewer.init(sock, %{thread: String.slice(id, 0, 6)})
    size = {80, 24}

    # Type a message and press enter.
    st =
      Enum.reduce(String.graphemes("edit it") ++ [:enter], st, fn key, st ->
        key = if is_binary(key), do: {:char, key}, else: key
        {:cont, st} = Viewer.key(key, st, size)
        st
      end)

    assert st.input == ""

    follow = fn follow, st, done? ->
      {:ok, data} = :gen_tcp.recv(sock, 0, 15_000)
      st = Viewer.frame(Client.decode(data), st)
      if done?.(st), do: st, else: follow.(follow, st, done?)
    end

    st = follow.(follow, st, &(&1.snap["status"] == "awaiting_approval"))
    assert %{state: "blocked", kind: "permission", msg: "Edit STRATTA_DEMO.md"} = Viewer.status(st)

    {rows, {23, 3}} = Viewer.render(st, size)
    screen = Enum.map(rows, &Render.plain/1)
    assert length(rows) == 24
    assert Enum.at(screen, 21) =~ "y approve  n deny"
    assert Enum.any?(screen, &(&1 =~ "+Request: edit it"))

    # "y" with an empty composer answers the approval instead of typing.
    {:cont, st} = Viewer.key({:char, "y"}, st, size)
    assert st.input == ""

    st = follow.(follow, st, &(&1.snap["status"] == "idle" and &1.turns == 1))
    assert %{state: "done"} = Viewer.status(st)
    {:cont, st} = Viewer.key(:up, st, size)
    assert %{state: "idle"} = Viewer.status(st)
    assert {:halt, :detached} = Viewer.key(:ctrl_d, st, size)
    assert File.exists?(Path.join(dir, "STRATTA_DEMO.md"))
  end

  test "open hands the thread to $STRATTA_OPENER", %{dir: dir} do
    {id, 0} = stratta(["new", "-p", dir])
    file = Path.join(dir, "opened")
    System.put_env("STRATTA_OPENER", ~s(printf '%s %s' "$STRATTA_THREAD" "$STRATTA_CWD" > #{file}))
    on_exit(fn -> System.delete_env("STRATTA_OPENER") end)

    assert {"", 0} = stratta(["open", id])
    assert [^id, cwd] = file |> File.read!() |> String.split(" ")
    assert cwd =~ ".stratta/worktrees"

    System.put_env("STRATTA_OPENER", "echo nope; exit 3")
    assert {:error, "The opener exited with status 3. nope"} = Open.run(%{"id" => id})
  end
end
