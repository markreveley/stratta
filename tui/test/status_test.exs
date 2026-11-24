defmodule Stratta.TUI.StatusTest do
  use ExUnit.Case, async: true

  alias Stratta.TUI.Status

  defp snapshot(status, items), do: %{"status" => status, "items" => items, "thread" => %{"title" => "Fix the bug"}}

  defp pairs("\e]7501;" <> rest) do
    rest
    |> String.trim_trailing("\e\\")
    |> String.split(":")
    |> Map.new(fn pair ->
      [key, value] = String.split(pair, "=", parts: 2)
      {key, if(key in ["msg", "title"], do: Base.decode64!(value), else: value)}
    end)
  end

  test "maps thread state to a report" do
    tool = %{"kind" => "tool", "status" => "in_progress", "title" => "Run tests"}
    approval = %{"kind" => "approval", "status" => "pending", "title" => "Edit lib/a.ex", "request_id" => "r1"}
    reply = %{"kind" => "assistant", "text" => "All green.\nDetails follow."}
    done = %{"kind" => "turn_end", "status" => "completed"}

    assert %{state: "working", msg: "Run tests"} = Status.report(snapshot("running", [tool]), true)

    assert %{state: "blocked", kind: "permission", msg: "Edit lib/a.ex"} =
             Status.report(snapshot("awaiting_approval", [tool, approval]), true)

    assert %{state: "done", msg: "All green."} = Status.report(snapshot("idle", [reply, done]), false)
    assert %{state: "idle"} = Status.report(snapshot("idle", [reply, done]), true)

    assert %{state: "error", msg: "boom"} =
             Status.report(snapshot("idle", [%{"kind" => "turn_end", "status" => "failed", "error" => "boom"}]), false)

    assert %{state: "idle", title: "Fix the bug"} = Status.report(snapshot("detached", []), true)
  end

  test "encodes an OSC 7501 report" do
    report = %{state: "blocked", kind: "permission", msg: "Apply 3 changes?", title: "Fix the bug"}

    assert pairs(Status.osc7501(report)) ==
             %{
               "state" => "blocked",
               "kind" => "permission",
               "app" => "stratta",
               "msg" => "Apply 3 changes?",
               "title" => "Fix the bug"
             }

    assert pairs(Status.osc7501(%{state: "idle"}, "thread/t1")) == %{
             "state" => "idle",
             "id" => "thread/t1",
             "app" => "stratta"
           }

    assert Status.clear("thread/t1") == "\e]7501;state=clear:id=thread/t1\e\\"
  end

  test "kind is only sent with blocked, and text is made safe and bounded" do
    hostile = "line one\nline two\t\e[31mred" <> <<0x202E::utf8>> <> String.duplicate("x", 5000)
    sent = pairs(Status.osc7501(%{state: "working", kind: "permission", msg: hostile}))

    refute Map.has_key?(sent, "kind")
    refute sent["msg"] =~ ~r/[\x00-\x1F\x7F]/
    refute sent["msg"] =~ <<0x202E::utf8>>
    assert String.starts_with?(sent["msg"], "line one line two [31mred")
    assert byte_size(sent["msg"]) <= 2048
    assert byte_size(Status.osc7501(%{state: "working", msg: hostile, title: hostile})) < 4096
  end

  test "progress fallback" do
    assert Status.osc94(%{state: "working"}) == "\e]9;4;3\a"
    assert Status.osc94(%{state: "blocked"}) == "\e]9;4;4;100\a"
    assert Status.osc94(%{state: "done"}) == "\e]9;4;0\a"
  end

  test "the status hook gets the report in its environment" do
    file = Path.join(System.tmp_dir!(), "stratta-hook-#{System.unique_integer([:positive])}")

    System.put_env(
      "STRATTA_STATUS_HOOK",
      ~s(printf '%s|%s|%s' "$STRATTA_STATE" "$STRATTA_KIND" "$STRATTA_THREAD" > #{file})
    )

    on_exit(fn -> System.delete_env("STRATTA_STATUS_HOOK") && File.rm(file) end)

    Status.hook(%{state: "blocked", kind: "permission", msg: "x"}, "t1")
    Enum.find(1..50, fn _ -> (File.exists?(file) && File.read!(file) != "") || (Process.sleep(20) && false) end)
    assert File.read!(file) == "blocked|permission|t1"
  end
end
