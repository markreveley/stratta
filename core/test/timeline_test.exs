defmodule Stratta.TimelineTest do
  use ExUnit.Case, async: true

  alias Jido.Harness.Event
  alias Stratta.Timeline

  defp ev(type, payload, opts \\ []) do
    Event.new!(
      type: type,
      provider: :demo,
      payload: payload,
      turn_id: opts[:turn] || "t1",
      sequence: opts[:seq] || 1,
      request_id: opts[:request_id],
      timestamp: "2026-01-01T00:00:00Z"
    )
  end

  test "merges consecutive text deltas and splits on kind change" do
    tl =
      Timeline.new()
      |> Timeline.add_user("t1", "hi")
      |> Timeline.apply_event(ev(:thinking_delta, %{"text" => "hmm "}))
      |> Timeline.apply_event(ev(:thinking_delta, %{"text" => "ok"}))
      |> Timeline.apply_event(ev(:output_text_delta, %{"text" => "Hello "}))
      |> Timeline.apply_event(ev(:output_text_delta, %{"text" => "world"}))

    assert [
             %{"kind" => "user"},
             %{"kind" => "thinking", "text" => "hmm ok"},
             %{"kind" => "assistant", "text" => "Hello world"}
           ] =
             tl.items
  end

  test "tool call is updated in place by tool results, keeping diffs" do
    diff = %{"type" => "diff", "path" => "/a.txt", "oldText" => "a", "newText" => "b"}

    tl =
      Timeline.new()
      |> Timeline.apply_event(
        ev(:tool_call, %{
          "toolCallId" => "x",
          "title" => "Edit",
          "kind" => "edit",
          "status" => "pending",
          "content" => [diff]
        })
      )
      |> Timeline.apply_event(ev(:tool_result, %{"toolCallId" => "x", "status" => "completed"}))

    assert [
             %{
               "kind" => "tool",
               "status" => "completed",
               "diffs" => [%{"path" => "/a.txt", "old" => "a", "new" => "b"}]
             }
           ] = tl.items
  end

  test "approvals resolve and expire with the turn" do
    req = %{"tool_call" => %{"title" => "Run rm"}, "options" => []}

    tl =
      Timeline.new()
      |> Timeline.apply_event(ev(:approval_requested, req, request_id: "r1"))
      |> Timeline.apply_event(ev(:approval_requested, req, request_id: "r2"))
      |> Timeline.apply_event(ev(:approval_resolved, %{"decision" => "approve"}, request_id: "r1"))
      |> Timeline.apply_event(ev(:turn_completed, %{}))

    assert [%{"status" => "approved"}, %{"status" => "expired"}, %{"kind" => "turn_end", "status" => "completed"}] =
             tl.items
  end

  test "tracks the live model from ACP config updates" do
    update = %{
      "sessionUpdate" => "config_option_update",
      "configOptions" => [%{"id" => "model", "currentValue" => "m2"}]
    }

    tl = Timeline.apply_event(Timeline.new(), ev(:provider_event, %{"kind" => "acp_update", "update" => update}))
    assert tl.model == "m2"
  end

  test "rebuilds indexes from persisted items" do
    tl = Timeline.new() |> Timeline.apply_event(ev(:tool_call, %{"toolCallId" => "x", "status" => "pending"}))
    reloaded = tl.items |> Jason.encode!() |> Jason.decode!() |> Timeline.new()
    reloaded = Timeline.apply_event(reloaded, ev(:tool_result, %{"toolCallId" => "x", "status" => "failed"}))
    assert [%{"status" => "failed"}] = reloaded.items
  end

  test "item ids continue after the highest stored id when a timeline is reloaded" do
    tl =
      Timeline.new()
      |> Timeline.add_user("t1", "add a greeting file")
      |> Timeline.apply_event(ev(:tool_call, %{"toolCallId" => "x", "title" => "Read README.md"}))
      |> Timeline.apply_event(ev(:approval_requested, %{"tool_call" => %{}, "options" => []}, request_id: "r1"))

    assert Enum.map(tl.items, & &1["id"]) == ["i1", "i2", "i3"]

    stored = tl.items |> Jason.encode!() |> Jason.decode!()

    reloaded =
      stored
      |> Timeline.new()
      |> Timeline.apply_event(ev(:tool_call, %{"toolCallId" => "y", "title" => "Run mix test"}, turn: "t2"))
      |> Timeline.apply_event(ev(:tool_result, %{"toolCallId" => "y", "status" => "completed"}, turn: "t2"))

    assert Enum.map(reloaded.items, & &1["id"]) == ["i1", "i2", "i3", "i4"]

    assert Enum.take(reloaded.items, 3) == stored
    assert %{"kind" => "tool", "status" => "completed", "title" => "Run mix test"} = List.last(reloaded.items)
  end

  test "a stored timeline with a repeated or missing id is given distinct ids on load" do
    stored = [
      %{"id" => "i1", "kind" => "user", "text" => "go"},
      %{"id" => "i2", "kind" => "tool", "tool_call_id" => "x", "status" => "completed"},
      %{"id" => "i1", "kind" => "tool", "tool_call_id" => "y", "status" => "pending"},
      %{"kind" => "notice", "text" => "no id"}
    ]

    tl = Timeline.new(stored)
    assert Enum.map(tl.items, & &1["id"]) == ["i1", "i2", "i3", "i4"]

    tl = Timeline.apply_event(tl, ev(:tool_result, %{"toolCallId" => "y", "status" => "failed"}))
    assert [%{"kind" => "user", "text" => "go"} = user, _, %{"tool_call_id" => "y", "status" => "failed"}, _] = tl.items
    refute Map.has_key?(user, "status")

    tl = Timeline.add_notice(tl, :info, "next")
    assert List.last(tl.items)["id"] == "i5"
  end

  test "close_dangling expires approvals from a turn that never finished" do
    tl =
      Timeline.new()
      |> Timeline.add_user("t1", "go")
      |> Timeline.apply_event(ev(:approval_requested, %{"tool_call" => %{}, "options" => []}, request_id: "r1"))
      |> Timeline.close_dangling()

    assert [%{"kind" => "user"}, %{"kind" => "approval", "status" => "expired"}, %{"kind" => "notice"}] = tl.items
  end

  test "close_dangling leaves finished threads alone" do
    tl = Timeline.new() |> Timeline.add_user("t1", "go") |> Timeline.apply_event(ev(:turn_completed, %{}))
    assert Timeline.close_dangling(tl) == tl
  end

  test "permission requests get letters that are never reused, even after a reload" do
    request = %{"tool_call" => %{"title" => "Edit"}, "options" => []}

    tl =
      Timeline.new()
      |> Timeline.apply_event(ev(:approval_requested, request, request_id: "r1"))
      |> Timeline.apply_event(ev(:approval_resolved, %{"decision" => "approve"}, request_id: "r1"))
      |> Timeline.apply_event(ev(:approval_requested, request, request_id: "r2"))

    assert ["a", "b"] = for(%{"kind" => "approval", "label" => label} <- tl.items, do: label)
    assert [%{"label" => "b"}] = Timeline.pending_approvals(tl)

    reloaded = tl.items |> Jason.encode!() |> Jason.decode!() |> Timeline.new()
    reloaded = Timeline.apply_event(reloaded, ev(:approval_requested, request, request_id: "r3"))
    assert List.last(reloaded.items)["label"] == "c"

    assert Enum.map([0, 25, 26, 27, 51, 52], &Timeline.approval_label/1) == ["a", "z", "aa", "ab", "az", "ba"]
  end
end
