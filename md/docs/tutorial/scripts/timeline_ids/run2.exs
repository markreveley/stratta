# Second lifetime: the saved items are loaded, as a restarted ThreadServer loads them, and
# one new tool call and its result are folded in.
[saved] = System.argv()
alias Stratta.Timeline
alias Jido.Harness.Event

tl = saved |> File.read!() |> :erlang.binary_to_term() |> Timeline.new()
before = Enum.find(tl.items, &(&1["kind"] == "user"))

tl =
  tl
  |> Timeline.apply_event(%Event{
    type: :tool_call,
    sequence: 1,
    turn_id: "turn-2",
    payload: %{"toolCallId" => "tc9", "title" => "Run mix test", "kind" => "execute", "status" => "in_progress"}
  })
  |> Timeline.apply_event(%Event{
    type: :tool_result,
    sequence: 2,
    turn_id: "turn-2",
    payload: %{"toolCallId" => "tc9", "status" => "completed", "title" => "Run mix test", "kind" => "execute"}
  })

ids = Enum.map(tl.items, & &1["id"])
later = Enum.find(tl.items, &(&1["kind"] == "user"))
show = &inspect(Map.take(&1, ["id", "kind", "text", "title", "status", "tool_kind"]))

IO.puts("run 2 items: " <> Enum.map_join(tl.items, ", ", &"#{&1["id"]}=#{&1["kind"]}"))
IO.puts("repeated ids: " <> inspect(ids -- Enum.uniq(ids)))
IO.puts("user message, as loaded:     " <> show.(before))
IO.puts("user message, after the run: " <> show.(later))
