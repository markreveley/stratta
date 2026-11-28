ExUnit.start(autorun: false)
Code.require_file("timeline_props_test.exs", __DIR__)
alias Spike.Run
show = fn name, ops ->
  {tl, _m} = Enum.reduce(ops, {Stratta.Timeline.new(), Run.new_model()}, fn op, {tl, m} -> {tl, m, _} = Run.step(op, tl, m); {tl, m} end)
  IO.puts("#{name}: " <> Enum.map_join(tl.items, " | ", fn i -> "#{i["id"]} #{i["kind"]}#{if i["status"], do: "=" <> i["status"], else: ""}#{if i["level"], do: "(" <> i["level"] <> ")", else: ""}" end))
end
show.("A reload x3 of an unfinished turn", [{:user, "a"}, {:restart}, {:restart}, {:restart}])
show.("B pending tool, finished turn, reload", [{:user, "a"}, {:tool_call, false}, {:turn_end, :turn_completed}, {:restart}])
show.("C in_progress tool, finished turn, reload", [{:user, "a"}, {:tool_call, false}, {:tool_result, 0, "in_progress"}, {:turn_end, :turn_interrupted}, {:restart}])
show.("D finished turn, reload x2", [{:user, "a"}, {:turn_end, :turn_completed}, {:restart}, {:restart}])
show.("E in_progress tool, open turn, reload", [{:user, "a"}, {:tool_call, false}, {:tool_result, 0, "in_progress"}, {:restart}])
