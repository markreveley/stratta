defmodule Stratta.ThreadFlowTest do
  # Drives a real Jido.Harness session against the bundled demo ACP agent.
  use ExUnit.Case, async: false

  alias Stratta.{Threads, ThreadServer}

  setup do
    dir = Path.join(System.tmp_dir!(), "stratta-flow-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["init", "-q", "-b", "main"], cd: dir)
    File.write!(Path.join(dir, "README.md"), "# x\n")
    {_, 0} = System.cmd("git", ["add", "."], cd: dir)
    {_, 0} = System.cmd("git", ["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "-q", "-m", "init"], cd: dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, project} = Threads.add_project(dir)
    {:ok, project: project}
  end

  defp await_snapshot(fun, timeout \\ 15_000) do
    receive do
      {:thread, _, snap} -> if fun.(snap), do: snap, else: await_snapshot(fun, timeout)
    after
      timeout -> flunk("timed out waiting for thread snapshot")
    end
  end

  test "approve an edit, see it in the diff, then commit", %{project: project} do
    {:ok, thread} = Threads.create_thread(project, %{"provider" => "demo", "worktree" => "true"})
    assert thread["worktree"]
    Phoenix.PubSub.subscribe(Stratta.PubSub, ThreadServer.topic(thread["id"]))

    assert {:ok, :sent} = ThreadServer.send_input(thread["id"], "create a file")

    snap = await_snapshot(&Enum.any?(&1.items, fn i -> i["kind"] == "approval" end))
    approval = Enum.find(snap.items, &(&1["kind"] == "approval"))
    assert :ok = ThreadServer.respond_approval(thread["id"], approval["request_id"], :approve)

    snap = await_snapshot(&Enum.any?(&1.items, fn i -> i["kind"] == "turn_end" end))
    assert snap.thread["title"] == "create a file"
    assert [%{path: "STRATTA_DEMO.md"}] = Threads.diff(snap.thread)
    assert {:ok, _} = Threads.commit(snap.thread, "demo")
  end

  test "denying leaves the workspace clean", %{project: project} do
    {:ok, thread} = Threads.create_thread(project, %{"provider" => "demo", "worktree" => "false"})
    Phoenix.PubSub.subscribe(Stratta.PubSub, ThreadServer.topic(thread["id"]))
    {:ok, :sent} = ThreadServer.send_input(thread["id"], "edit something")

    snap = await_snapshot(&Enum.any?(&1.items, fn i -> i["kind"] == "approval" end))
    approval = Enum.find(snap.items, &(&1["kind"] == "approval"))
    :ok = ThreadServer.respond_approval(thread["id"], approval["request_id"], :deny)

    await_snapshot(&Enum.any?(&1.items, fn i -> i["kind"] == "turn_end" end))
    assert Threads.diff(Threads.get_thread(thread["id"])) == []
  end

  test "follow-ups queue while a turn runs and history survives a restart", %{project: project} do
    {:ok, thread} = Threads.create_thread(project, %{"provider" => "demo", "worktree" => "false"})
    Phoenix.PubSub.subscribe(Stratta.PubSub, ThreadServer.topic(thread["id"]))
    {:ok, :sent} = ThreadServer.send_input(thread["id"], "hello")
    {:ok, :queued} = ThreadServer.send_input(thread["id"], "and again")

    await_snapshot(&(Enum.count(&1.items, fn i -> i["kind"] == "turn_end" end) == 2))

    [{pid, _}] = Registry.lookup(Stratta.ThreadRegistry, thread["id"])
    DynamicSupervisor.terminate_child(Stratta.ThreadSupervisor, pid)
    snap = ThreadServer.snapshot(thread["id"])
    assert Enum.count(snap.items, &(&1["kind"] == "user")) == 2
    assert snap.status == :detached
  end
end
