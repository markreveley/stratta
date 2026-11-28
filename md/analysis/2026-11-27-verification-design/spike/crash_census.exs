# Feeds hostile event streams to Timeline.apply_event/2 and buckets every exception
# by the line of timeline.ex that raised it.
for {k, v} <- [initial_size: 1, max_runs: 100, max_run_time: :infinity, max_shrinking_steps: 0, inspect_opts: []],
    do: Application.put_env(:stream_data, k, v)

ExUnit.start(autorun: false)
Code.require_file("timeline_props_test.exs", __DIR__)
alias Jido.Harness.Event
alias Stratta.Timeline

sites =
  Spike.Gen.hostile_op()
  |> StreamData.list_of(min_length: 1, max_length: 6)
  |> Stream.take(String.to_integer(System.get_env("N", "20000")))
  |> Enum.reduce(%{}, fn ops, acc ->
    Enum.reduce_while(ops, {Timeline.new(), 0, acc}, fn
      {:restart}, {tl, n, acc} ->
        {:cont, {tl.items |> Spike.Run.roundtrip() |> Timeline.new() |> Timeline.close_dangling(), n, acc}}

      {:event, type, payload, turn, req}, {tl, n, acc} ->
        e = Event.new!(type: type, provider: :demo, payload: payload, turn_id: turn, sequence: n + 1, request_id: req)

        try do
          {:cont, {Timeline.apply_event(tl, e), n + 1, acc}}
        rescue
          ex ->
            line =
              Enum.find_value(__STACKTRACE__, fn {mod, fun, _a, loc} ->
                if mod == Timeline, do: {fun, loc[:line]}
              end)

            key = {type, line, ex.__struct__}
            {:halt, {tl, n, Map.update(acc, key, {1, payload}, fn {c, p} -> {c + 1, p} end)}}
        end
    end)
    |> elem(2)
  end)

for {{type, {fun, line}, ex}, {count, payload}} <- Enum.sort_by(sites, fn {{_, {_, l}, _}, _} -> l end) do
  IO.puts("#{line}\t#{fun}\t#{type}\t#{inspect(ex)}\t#{count}\t#{inspect(payload)}")
end
