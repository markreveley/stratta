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
end
