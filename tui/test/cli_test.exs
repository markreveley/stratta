defmodule Stratta.TUI.CLITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Stratta.TUI.{CLI, Client, Dashboard, Open, Render, Viewer}

  setup do
    dir = Path.join(System.tmp_dir!(), "stratta-cli-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    git = fn args -> {_, 0} = System.cmd("git", args, cd: dir, stderr_to_stdout: true) end
    git.(["init", "-q", "-b", "main"])
    git.(["config", "user.email", "a@b.c"])
    git.(["config", "user.name", "t"])
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

  defp new_thread(dir, extra \\ []), do: json(["new", "-p", dir] ++ extra)

  defp screen(module, st, size) do
    {rows, _cursor} = module.render(st, size)
    Enum.map(rows, &Render.plain/1)
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

  test "new, approve by label, diff, commit from the command line", %{dir: dir} do
    {out, 0} = stratta(["new", "-p", dir, "create", "a", "file"])
    assert [_, slot, id] = Regex.run(~r/^Thread (\d+) · (t[\w-]{8})$/, out)

    assert %{"status" => "awaiting_approval"} =
             wait_until(fn -> (s = json(["status", slot])) && s["status"] == "awaiting_approval" && s end)

    {listing, 0} = stratta(["ls"])
    assert listing =~ "needs approval #{slot}a"
    {status, 0} = stratta(["status", slot])
    assert status =~ "waiting on   #{slot}a Edit STRATTA_DEMO.md"

    assert capture_io(:stderr, fn -> assert CLI.run(["approve", slot <> "b"]) == 1 end) =~ "has no request b"
    assert {"Approved #{slot}a: Edit STRATTA_DEMO.md", 0} == stratta(["approve", slot <> "a"])
    wait_until(fn -> json(["status", id])["status"] == "idle" end)

    assert capture_io(:stderr, fn -> assert CLI.run(["approve", slot <> "a"]) == 1 end) =~
             "#{slot}a was already approved"

    assert %{"files" => [%{"path" => "STRATTA_DEMO.md"}]} = json(["diff", slot])
    assert {out, 0} = stratta(["commit", slot, "-m", "demo"])
    assert out =~ "demo"
    assert capture_io(:stderr, fn -> assert CLI.run(["push", slot]) == 1 end) =~ "no git remote"
  end

  test "the current thread: new sets it, use switches it, commands default to it", %{dir: dir} do
    first = new_thread(dir, ["--no-worktree"])
    second = new_thread(dir, ["--no-worktree"])
    assert second["slot"] != first["slot"]

    assert json(["status"])["thread"]["id"] == second["id"]
    {listing, 0} = stratta(["ls"])
    assert listing =~ ~r/^\*\s+#{second["slot"]}\s/m
    refute listing =~ ~r/^\*\s+#{first["slot"]}\s/m

    assert {"Now on thread #{first["slot"]} · New thread", 0} == stratta(["use", to_string(first["slot"])])
    assert json(["status"])["thread"]["id"] == first["id"]
    assert {"On thread #{first["slot"]} · New thread", 0} == stratta(["use"])

    assert {"Sent.", 0} = stratta(["send", "hello", "there"])
    assert wait_until(fn -> json(["status", first["id"]])["thread"]["title"] == "hello there" end)
    assert {"Sent.", 0} = stratta(["send", to_string(second["slot"]), "to", "the", "other"])
    assert wait_until(fn -> json(["status", second["id"]])["thread"]["title"] == "to the other" end)
    wait_until(fn -> json(["status", first["id"]])["status"] == "idle" end)
    assert {_, 0} = stratta(["send", "-t", to_string(first["slot"]), "2", "more", "things"])
    assert wait_until(fn -> Enum.any?(json(["status", first["id"]])["items"], &(&1["text"] == "2 more things")) end)
  end

  test "slots can be moved and freed", %{dir: dir} do
    a = new_thread(dir, ["--no-worktree"])
    b = new_thread(dir, ["--no-worktree"])

    assert {out, 0} = stratta(["slot", to_string(b["slot"]), to_string(a["slot"])])
    assert out =~ "is now in slot #{a["slot"]}"
    assert json(["status", to_string(a["slot"])])["thread"]["id"] == b["id"]
    assert json(["status", to_string(b["slot"])])["thread"]["id"] == a["id"]

    assert {out, 0} = stratta(["unslot", a["id"]])
    assert out =~ "still reachable as #{a["id"]}"

    assert capture_io(:stderr, fn -> assert CLI.run(["status", to_string(b["slot"])]) == 1 end) =~
             "No thread is in slot"

    assert {"Deleted #{a["id"]}.", 0} == stratta(["rm", a["id"]])
  end

  test "the viewer follows a thread, answers an approval and reports status", %{dir: dir} do
    %{"id" => id, "slot" => slot} = new_thread(dir, ["--no-worktree"])
    {:ok, sock} = Client.connect()
    {:ok, st} = Viewer.init(sock, %{thread: to_string(slot)})
    size = {80, 24}

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
    lines = Enum.map(rows, &Render.plain/1)
    assert length(rows) == 24
    assert hd(lines) =~ "● #{slot} edit it"
    assert Enum.at(lines, 21) =~ "⚠ #{slot}a Edit STRATTA_DEMO.md"
    assert Enum.at(lines, 21) =~ "y approve  n deny"
    assert Enum.any?(lines, &(&1 =~ "⚠ #{slot}a Edit STRATTA_DEMO.md — waiting for you"))
    assert Enum.any?(lines, &(&1 =~ "+Request: edit it"))

    {:cont, st} = Viewer.key({:char, "y"}, st, size)
    assert st.input == ""

    st = follow.(follow, st, &(&1.snap["status"] == "idle" and &1.turns == 1))
    assert %{state: "done"} = Viewer.status(st)
    {:cont, st} = Viewer.key(:up, st, size)
    assert %{state: "idle"} = Viewer.status(st)
    assert {:halt, :detached} = Viewer.key(:ctrl_d, st, size)
    assert File.exists?(Path.join(dir, "STRATTA_DEMO.md"))
    assert id == st.id
  end

  test "the dashboard lists threads and requests, and follows the current thread", %{dir: dir} do
    first = new_thread(dir, ["--no-worktree"])
    second = new_thread(dir, ["--no-worktree"])
    {:ok, sock} = Client.connect()
    {:ok, st} = Dashboard.init(sock, %{workspace: "default"})
    assert st.current == second["id"]

    follow = fn follow, st, done? ->
      if done?.(st) do
        st
      else
        {:ok, data} = :gen_tcp.recv(sock, 0, 15_000)
        follow.(follow, Dashboard.frame(Client.decode(data), st), done?)
      end
    end

    {_, 0} = stratta(["send", to_string(first["slot"]), "edit", "something"])
    name = "#{first["slot"]}a"

    st = follow.(follow, st, fn st -> Enum.any?(st.threads, &(&1["id"] == first["id"] and &1["pending"] != [])) end)
    wide = screen(Dashboard, st, {120, 30})
    assert Enum.any?(wide, &(&1 =~ ~r/Threads\s+Waiting on you/))
    assert Enum.any?(wide, &(&1 =~ ~r/ #{first["slot"]} ⚠ edit something  demo/))
    assert Enum.any?(wide, &(&1 =~ ~r/\s#{name}\s+Edit STRATTA_DEMO\.md/))
    assert hd(wide) =~ "1 waiting on you"
    assert Enum.all?(wide, &(String.length(&1) <= 120))
    assert length(wide) == 30

    narrow = screen(Dashboard, st, {60, 20})
    assert Enum.any?(narrow, &(&1 =~ ~r/^\s+#{name}\s+Edit STRATTA_DEMO\.md/))
    assert length(narrow) == 20

    {_, 0} = stratta(["use", to_string(first["slot"])])
    st = follow.(follow, st, &(&1.current == first["id"] and &1.snap != nil))
    shown = screen(Dashboard, st, {120, 30})
    assert Enum.any?(shown, &(&1 =~ "── #{first["slot"]} · edit something · demo · needs approval"))
    assert Enum.any?(shown, &(&1 =~ "⚠ #{name} Edit STRATTA_DEMO.md — waiting for you"))
    assert %{root: %{state: "blocked"}} = Dashboard.status(st)

    slotted = Enum.filter(st.threads, & &1["slot"])
    next = Enum.at(slotted, Enum.find_index(slotted, &(&1["id"] == first["id"])) + 1)["id"]
    {:cont, st} = Dashboard.key(:down, st, {120, 30})
    assert st.current == next
    wait_until(fn -> json(["use"])["thread"]["id"] == next end)
    assert {:halt, {:open, ^next}} = Dashboard.key(:enter, st, {120, 30})

    assert {"Denied #{name}: Edit STRATTA_DEMO.md", 0} == stratta(["deny", name])
  end

  test "open hands the thread to $STRATTA_OPENER", %{dir: dir} do
    %{"id" => id} = new_thread(dir)
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
