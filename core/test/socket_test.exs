defmodule Stratta.SocketTest do
  use ExUnit.Case, async: false

  setup do
    dir = Path.join(System.tmp_dir!(), "stratta-sock-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    git = fn args -> {_, 0} = System.cmd("git", args, cd: dir, stderr_to_stdout: true) end
    git.(["init", "-q", "-b", "main"])
    git.(["config", "user.email", "a@b.c"])
    git.(["config", "user.name", "t"])
    File.write!(Path.join(dir, "README.md"), "# x\n")
    git.(["add", "."])
    git.(["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "-q", "-m", "init"])
    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, sock} = :gen_tcp.connect({:local, Stratta.Socket.path()}, 0, [:binary, packet: 4, active: false])
    on_exit(fn -> :gen_tcp.close(sock) end)
    {:ok, sock: sock, dir: dir}
  end

  defp request(sock, id, op, args) do
    :ok = :gen_tcp.send(sock, Jason.encode!(%{id: id, op: op, args: args}))
  end

  defp recv(sock, timeout \\ 15_000) do
    {:ok, data} = :gen_tcp.recv(sock, 0, timeout)
    Jason.decode!(data)
  end

  defp recv_until(sock, fun) do
    frame = recv(sock)
    fun.(frame) || recv_until(sock, fun)
  end

  defp call(sock, id, op, args \\ %{}) do
    request(sock, id, op, args)
    recv_until(sock, fn frame -> frame["id"] == id && frame end)
  end

  test "ping and errors", %{sock: sock} do
    assert %{"ok" => true, "result" => %{"version" => _}} = call(sock, 1, "ping")
    assert %{"ok" => false, "error" => "Unknown" <> _} = call(sock, 2, "nope")
    assert %{"ok" => false, "error" => "No thread matches" <> _} = call(sock, 3, "thread.get", %{"thread" => "zzz"})

    assert %{"ok" => false, "error" => "Unknown agent" <> _} =
             call(sock, 4, "threads.create", %{"project" => "/tmp", "provider" => "nope"})

    assert %{"ok" => false, "error" => "sandbox_mode must be one of" <> _} =
             call(sock, 5, "threads.create", %{"project" => "/tmp", "provider" => "demo", "sandbox_mode" => "nope"})
  end

  test "the socket is private to its owner" do
    assert {:ok, %{mode: mode}} = File.stat(Stratta.Socket.path())
    assert Bitwise.band(mode, 0o077) == 0
  end

  test "create, subscribe, approve, diff and commit over the socket", %{sock: sock, dir: dir} do
    assert %{"ok" => true, "result" => thread} =
             call(sock, 1, "threads.create", %{"project" => dir, "provider" => "demo", "worktree" => true})

    id = thread["id"]
    prefix = String.slice(id, 0, 5)

    assert %{"ok" => true, "result" => %{"thread" => ^id, "snapshot" => %{"status" => "detached"}}} =
             call(sock, 2, "subscribe", %{"thread" => prefix})

    request(sock, 3, "thread.send", %{"thread" => prefix, "text" => "create a file"})

    recv_until(sock, fn frame ->
      frame["event"] == "thread" && frame["snapshot"]["status"] == "awaiting_approval"
    end)

    assert %{"ok" => true, "result" => %{"decision" => "approve"}} = call(sock, 4, "thread.approve", %{"thread" => id})

    snapshot =
      recv_until(sock, fn frame ->
        frame["event"] == "thread" && Enum.any?(frame["snapshot"]["items"], &(&1["kind"] == "turn_end")) &&
          frame["snapshot"]
      end)

    assert snapshot["thread"]["title"] == "create a file"

    assert %{
             "ok" => true,
             "result" => %{"files" => [%{"path" => "STRATTA_DEMO.md", "status" => "added"}], "text" => text}
           } =
             call(sock, 5, "thread.diff", %{"thread" => id})

    assert text =~ "+Request: create a file"
    assert %{"ok" => true} = call(sock, 6, "thread.commit", %{"thread" => id, "message" => "demo"})

    assert %{"ok" => false, "error" => "This repository has no git remote" <> _} =
             call(sock, 7, "thread.push", %{"thread" => id})

    assert %{"ok" => false, "error" => "Nothing is waiting" <> _} = call(sock, 8, "thread.approve", %{"thread" => id})
  end

  test "an overview subscription hears about status changes", %{sock: sock, dir: dir} do
    assert %{"ok" => true, "result" => %{"threads" => _}} = call(sock, 1, "subscribe", %{"all" => true})

    %{"result" => %{"id" => id}} =
      call(sock, 2, "threads.create", %{
        "project" => dir,
        "provider" => "demo",
        "worktree" => false,
        "message" => "hello"
      })

    recv_until(sock, fn frame ->
      frame["event"] == "threads" && Enum.any?(frame["threads"], &(&1["id"] == id and &1["status"] == "running"))
    end)

    recv_until(sock, fn frame ->
      frame["event"] == "threads" && Enum.any?(frame["threads"], &(&1["id"] == id and &1["status"] == "idle"))
    end)
  end

  test "slots: lowest free on create, addressable by number, movable, freed on delete", %{sock: sock, dir: dir} do
    create = fn id ->
      call(sock, id, "threads.create", %{"project" => dir, "provider" => "demo", "worktree" => false})["result"]
    end

    first = create.(1)
    second = create.(2)
    assert second["slot"] == first["slot"] + 1

    slot = Integer.to_string(first["slot"])
    id = first["id"]
    assert %{"result" => %{"thread" => %{"id" => ^id}}} = call(sock, 3, "thread.get", %{"thread" => slot})
    assert %{"ok" => false, "error" => "No thread is in slot 98."} = call(sock, 4, "thread.get", %{"thread" => "98"})

    assert %{"ok" => true} = call(sock, 5, "thread.slot", %{"thread" => second["id"], "slot" => first["slot"]})
    assert %{"result" => %{"thread" => %{"slot" => swapped}}} = call(sock, 6, "thread.get", %{"thread" => first["id"]})
    assert swapped == second["slot"]

    assert %{"ok" => true} = call(sock, 7, "thread.delete", %{"thread" => second["id"]})
    assert create.(8)["slot"] == first["slot"]

    assert %{"result" => %{"slot" => nil}} = call(sock, 9, "thread.slot", %{"thread" => first["id"], "slot" => nil})
    assert %{"ok" => true} = call(sock, 10, "thread.get", %{"thread" => first["id"]})

    assert %{"ok" => false, "error" => "A slot is a number" <> _} =
             call(sock, 11, "thread.slot", %{"thread" => first["id"], "slot" => 0})
  end

  test "requests are answered by label, and a used label is refused", %{sock: sock, dir: dir} do
    %{"result" => %{"id" => id, "slot" => slot}} =
      call(sock, 1, "threads.create", %{"project" => dir, "provider" => "demo", "worktree" => false})

    call(sock, 2, "subscribe", %{"all" => true})

    wait_for_request = fn ->
      recv_until(sock, fn frame ->
        frame["event"] == "threads" &&
          Enum.find_value(frame["threads"], fn t -> t["id"] == id && t["pending"] != [] && hd(t["pending"]) end)
      end)
    end

    request(sock, 3, "thread.send", %{"thread" => id, "text" => "edit one"})
    assert %{"label" => "a", "title" => "Edit STRATTA_DEMO.md"} = wait_for_request.()

    assert %{"ok" => false, "error" => "This thread has no request b."} =
             call(sock, 4, "thread.approve", %{"thread" => "#{slot}b"})

    assert %{"ok" => true, "result" => %{"label" => label, "title" => "Edit STRATTA_DEMO.md"}} =
             call(sock, 5, "thread.approve", %{"thread" => "#{slot}a"})

    assert label == "#{slot}a"

    recv_until(sock, fn frame ->
      frame["event"] == "threads" && Enum.any?(frame["threads"], &(&1["id"] == id and &1["status"] == "idle"))
    end)

    request(sock, 6, "thread.send", %{"thread" => id, "text" => "edit two"})
    assert %{"label" => "b"} = wait_for_request.()
    assert %{"ok" => false, "error" => error} = call(sock, 7, "thread.approve", %{"thread" => "#{slot}a"})
    assert error == "#{slot}a was already approved."

    assert %{"ok" => true, "result" => %{"decision" => "deny"}} =
             call(sock, 8, "thread.approve", %{"thread" => slot, "decision" => "deny"})
  end

  test "a workspace's current thread is shared and pushed to subscribers", %{sock: sock, dir: dir} do
    ws = "ws-#{System.unique_integer([:positive])}"
    assert %{"result" => %{"thread" => nil}} = call(sock, 1, "subscribe", %{"current" => ws})

    %{"result" => %{"id" => first}} =
      call(sock, 2, "threads.create", %{"project" => dir, "provider" => "demo", "worktree" => false, "workspace" => ws})

    %{"result" => %{"id" => second, "slot" => slot}} =
      call(sock, 3, "threads.create", %{"project" => dir, "provider" => "demo", "worktree" => false})

    assert %{"result" => %{"thread" => %{"id" => ^first}}} = call(sock, 4, "current.get", %{"workspace" => ws})
    request(sock, 5, "current.set", %{"workspace" => ws, "thread" => Integer.to_string(slot)})
    assert %{"thread" => ^second} = recv_until(sock, &(&1["event"] == "current" && &1))

    assert %{"result" => %{"thread" => other}} = call(sock, 6, "current.get", %{"workspace" => ws <> "-other"})
    assert other == nil
    request(sock, 7, "thread.delete", %{"thread" => second})
    assert %{"thread" => nil} = recv_until(sock, &(&1["event"] == "current" && &1))
  end
end
