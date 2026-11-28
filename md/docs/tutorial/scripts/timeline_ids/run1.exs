# First lifetime of the virtual machine: a thread gets a user message, a tool call and a
# permission request, and its items are written to a file as a save would write them.
[out] = System.argv()
alias Stratta.Timeline
alias Jido.Harness.Event

tl =
  Timeline.new()
  |> Timeline.add_user("turn-1", "add a greeting file")
  |> Timeline.apply_event(%Event{
    type: :tool_call,
    sequence: 1,
    turn_id: "turn-1",
    payload: %{"toolCallId" => "tc1", "title" => "Read README.md", "kind" => "read"}
  })
  |> Timeline.apply_event(%Event{
    type: :approval_requested,
    sequence: 2,
    turn_id: "turn-1",
    request_id: "req-1",
    payload: %{"tool_call" => %{"title" => "Write hello.txt", "kind" => "edit"}}
  })

File.write!(out, :erlang.term_to_binary(tl.items))
IO.puts("run 1 saved: " <> Enum.map_join(tl.items, ", ", &"#{&1["id"]}=#{&1["kind"]}"))
