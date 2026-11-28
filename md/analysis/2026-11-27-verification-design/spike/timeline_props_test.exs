# Spike: Stratta.Timeline checked as a state machine.
#
# A generated list of operations is run against the real Timeline and, beside it, a
# small model of what a thread should hold. After every step each invariant is
# evaluated. One property per invariant, so a failure names the rule that broke.
#
# Nothing here reads timeline.ex's private functions.

defmodule Spike.Run do
  alias Jido.Harness.Event
  alias Stratta.Timeline

  @kinds ~w(user assistant thinking tool plan approval turn_end notice)

  def roundtrip(items), do: items |> Jason.encode!() |> Jason.decode!()

  def new_model do
    %{
      n: 0,
      seq: 0,
      turn: nil,
      queue: [],
      turn_tools: [],
      all_tools: [],
      pending: [],
      answered: %{},
      expect: %{},
      users: 0,
      ended: [],
      labels: 0
    }
  end

  defp ev(m, type, payload, opts \\ []) do
    m = %{m | seq: m.seq + 1}

    e =
      Event.new!(
        type: type,
        provider: :demo,
        payload: payload,
        turn_id: Keyword.get(opts, :turn, m.turn),
        sequence: m.seq,
        request_id: opts[:request_id],
        timestamp: "2026-01-01T00:00:00Z"
      )

    {e, m}
  end

  defp fresh(m, prefix), do: {"#{prefix}_#{m.n + 1}", %{m | n: m.n + 1}}

  defp expect_add(m, kind, text) do
    cur = Map.get(m.expect, m.turn, %{"assistant" => "", "thinking" => ""})
    %{m | expect: Map.put(m.expect, m.turn, Map.update!(cur, kind, &(&1 <> text)))}
  end

  # -- one step ---------------------------------------------------------------
  # Returns {timeline, model, tag}. An operation that does not apply is skipped.

  def step({:user, text}, tl, m) do
    {t, m} = fresh(m, "turn")
    m = %{m | users: m.users + 1}

    if m.turn == nil do
      {Timeline.add_user(tl, t, text, %{"mode" => "sent"}), %{m | turn: t, turn_tools: []}, :ok}
    else
      {Timeline.add_user(tl, t, text, %{"mode" => "queued"}), %{m | queue: m.queue ++ [t]}, :ok}
    end
  end

  def step({:notice}, tl, m), do: {Timeline.add_notice(tl, :info, "note"), m, :ok}

  def step({:restart}, tl, m) do
    open? = m.turn != nil or m.queue != []
    tl = tl.items |> roundtrip() |> Timeline.new() |> Timeline.close_dangling()
    {tl, %{m | turn: nil, queue: [], turn_tools: [], pending: [], seq: 0}, {:restarted, open?}}
  end

  def step(_op, tl, %{turn: nil} = m), do: {tl, m, :skip}

  def step({:delta, kind, text}, tl, m) do
    type = if kind == "assistant", do: :output_text_delta, else: :thinking_delta
    {e, m} = ev(m, type, %{"text" => text})
    {Timeline.apply_event(tl, e), expect_add(m, kind, text), :ok}
  end

  def step({:final, text}, tl, m) do
    sofar = get_in(m.expect, [m.turn, "assistant"]) || ""
    full = if sofar == "", do: text, else: sofar
    {e, m} = ev(m, :output_text_final, %{"text" => full})
    m = if sofar == "", do: expect_add(m, "assistant", text), else: m
    {Timeline.apply_event(tl, e), m, :ok}
  end

  def step({:tool_call, diff?}, tl, m) do
    {id, m} = fresh(m, "tc")
    content = if diff?, do: [%{"type" => "diff", "path" => "/a", "oldText" => "a", "newText" => "b"}], else: []
    payload = %{"toolCallId" => id, "title" => "Edit", "kind" => "edit", "status" => "pending", "content" => content}
    {e, m} = ev(m, :tool_call, payload)
    {Timeline.apply_event(tl, e), %{m | turn_tools: m.turn_tools ++ [id], all_tools: m.all_tools ++ [id]}, :ok}
  end

  def step({:tool_result, _i, _s}, tl, %{turn_tools: []} = m), do: {tl, m, :skip}

  def step({:tool_result, i, status}, tl, m) do
    id = Enum.at(m.turn_tools, rem(i, length(m.turn_tools)))
    {e, m} = ev(m, :tool_result, %{"toolCallId" => id, "status" => status})
    {Timeline.apply_event(tl, e), m, :ok}
  end

  def step({:cmd_output, _t}, tl, %{turn_tools: []} = m), do: {tl, m, :skip}

  def step({:cmd_output, text}, tl, m) do
    {e, m} = ev(m, :command_output_delta, %{"text" => text})
    {Timeline.apply_event(tl, e), m, :ok}
  end

  def step({:plan, n}, tl, m) do
    {e, m} = ev(m, :plan_updated, %{"entries" => Enum.map(0..n, &%{"content" => "step #{&1}"})})
    {Timeline.apply_event(tl, e), m, :ok}
  end

  def step({:usage}, tl, m) do
    {e, m} = ev(m, :usage, %{"input_tokens" => 1})
    {Timeline.apply_event(tl, e), m, :ok}
  end

  def step({:approval_req}, tl, m) do
    {r, m} = fresh(m, "req")
    payload = %{"tool_call" => %{"title" => "Edit", "kind" => "edit"}, "options" => []}
    {e, m} = ev(m, :approval_requested, payload, request_id: r)
    {Timeline.apply_event(tl, e), %{m | pending: m.pending ++ [r], labels: m.labels + 1}, :ok}
  end

  def step({:answer, _i, _d}, tl, %{pending: []} = m), do: {tl, m, :skip}

  # What ThreadServer does: mark the request locally, then the session confirms.
  def step({:answer, i, decision}, tl, m) do
    r = Enum.at(m.pending, rem(i, length(m.pending)))
    status = if decision == :approve, do: "approved", else: "denied"
    tl = Timeline.resolve_approval(tl, r, status)
    {e, m} = ev(m, :approval_resolved, %{"decision" => Atom.to_string(decision)}, request_id: r)
    {Timeline.apply_event(tl, e), %{m | pending: m.pending -- [r], answered: Map.put(m.answered, r, status)}, :ok}
  end

  def step({:turn_end, type}, tl, m) do
    {e, m} = ev(m, type, %{})
    tl = Timeline.apply_event(tl, e)
    ended = m.turn
    {next, queue} = List.pop_at(m.queue, 0)
    {tl, %{m | ended: m.ended ++ [ended], turn: next, queue: queue, turn_tools: [], pending: []}, {:ended, ended}}
  end

  # -- invariants -------------------------------------------------------------
  # Each returns true when it holds. `prev` is the item list before the step.

  def invariants do
    [
      ids_unique: fn _prev, tl, _m, _tag ->
        ids = Enum.map(tl.items, & &1["id"])
        ids == Enum.uniq(ids)
      end,
      append_only: fn prev, tl, _m, _tag ->
        before = Enum.map(prev, &{&1["id"], &1["kind"]})
        before == tl.items |> Enum.take(length(prev)) |> Enum.map(&{&1["id"], &1["kind"]})
      end,
      item_shape: fn _prev, tl, _m, _tag ->
        Enum.all?(tl.items, fn i ->
          is_binary(i["id"]) and Regex.match?(~r/^i[1-9]\d*$/, i["id"]) and i["kind"] in @kinds and is_binary(i["at"])
        end)
      end,
      labels_never_reused: fn _prev, tl, m, _tag ->
        labels = for %{"kind" => "approval", "label" => l} <- tl.items, do: l
        labels == Enum.map(0..(m.labels - 1)//1, &Timeline.approval_label/1)
      end,
      answer_is_final: fn prev, tl, m, _tag ->
        now = Map.new(tl.items, &{&1["id"], &1})

        Enum.all?(prev, fn
          %{"kind" => "approval", "status" => s, "id" => id} when s != "pending" -> now[id]["status"] == s
          _ -> true
        end) and
          Enum.all?(m.answered, fn {r, s} ->
            Enum.any?(tl.items, &(&1["request_id"] == r and &1["status"] == s))
          end)
      end,
      pending_is_what_waits: fn _prev, tl, m, _tag ->
        Enum.map(Timeline.pending_approvals(tl), & &1["request_id"]) == m.pending
      end,
      turn_end_expires: fn _prev, tl, _m, tag ->
        case tag do
          {:ended, t} ->
            not Enum.any?(tl.items, &(&1["kind"] == "approval" and &1["turn_id"] == t and &1["status"] == "pending"))

          _ ->
            true
        end
      end,
      turn_end_closes_tools: fn _prev, tl, _m, tag ->
        case tag do
          {:ended, t} ->
            not Enum.any?(
              tl.items,
              &(&1["kind"] == "tool" and &1["turn_id"] == t and &1["status"] in ["pending", "in_progress"])
            )

          _ ->
            true
        end
      end,
      restart_notice_only_if_unfinished: fn prev, tl, _m, tag ->
        case tag do
          {:restarted, open?} ->
            added = Enum.drop(tl.items, length(prev))
            open? or not Enum.any?(added, &(&1["kind"] == "notice" and &1["level"] == "warn"))

          _ ->
            true
        end
      end,
      restart_leaves_nothing_open: fn _prev, tl, _m, tag ->
        not match?({:restarted, _}, tag) or
          not Enum.any?(tl.items, &(&1["kind"] in ["approval", "tool"] and &1["status"] in ["pending", "in_progress"]))
      end,
      reload_is_identity: fn _prev, tl, _m, _tag ->
        r = tl.items |> roundtrip() |> Timeline.new()

        r.items == tl.items and r.tools == tl.tools and r.approvals == tl.approvals and
          r.approval_seq == tl.approval_seq and r.item_seq == tl.item_seq
      end,
      text_conserved: fn _prev, tl, m, _tag ->
        Enum.all?(m.expect, fn {turn, by_kind} ->
          Enum.all?(by_kind, fn {kind, text} ->
            text == for(%{"kind" => ^kind, "turn_id" => ^turn, "text" => t} <- tl.items, into: "", do: t)
          end)
        end)
      end,
      one_item_per_tool: fn _prev, tl, m, _tag ->
        ids = for %{"kind" => "tool", "tool_call_id" => id} <- tl.items, do: id
        Enum.sort(ids) == Enum.sort(m.all_tools)
      end,
      nothing_lost: fn _prev, tl, m, _tag ->
        Enum.count(tl.items, &(&1["kind"] == "user")) == m.users and
          Enum.sort(for(%{"kind" => "turn_end", "turn_id" => t} <- tl.items, do: t)) == Enum.sort(m.ended)
      end
    ]
  end

  @doc "Runs the operations and returns %{invariant => first violation}."
  def run(ops) do
    {_tl, _m, bad} =
      ops
      |> Enum.with_index()
      |> Enum.reduce({Timeline.new(), new_model(), %{}}, fn {op, at}, {tl, m, bad} ->
        prev = tl.items
        {tl, m, tag} = step(op, tl, m)

        bad =
          Enum.reduce(invariants(), bad, fn {name, holds?}, bad ->
            if Map.has_key?(bad, name) or holds?.(prev, tl, m, tag),
              do: bad,
              else: Map.put(bad, name, %{step: at, op: op, items: tl.items})
          end)

        {tl, m, bad}
      end)

    bad
  end
end

defmodule Spike.Gen do
  import StreamData

  def text, do: string(:alphanumeric, min_length: 1, max_length: 5)

  def op do
    frequency([
      {3, tuple({constant(:user), text()})},
      {6, tuple({constant(:delta), member_of(["assistant", "thinking"]), text()})},
      {1, tuple({constant(:final), text()})},
      {3, tuple({constant(:tool_call), boolean()})},
      {3, tuple({constant(:tool_result), integer(0..5), member_of(~w(completed failed in_progress))})},
      {2, tuple({constant(:cmd_output), text()})},
      {1, tuple({constant(:plan), integer(0..2)})},
      {1, constant({:usage})},
      {3, constant({:approval_req})},
      {3, tuple({constant(:answer), integer(0..5), member_of([:approve, :deny])})},
      {3, tuple({constant(:turn_end), member_of([:turn_completed, :turn_failed, :turn_interrupted])})},
      {1, constant({:notice})},
      {2, constant({:restart})}
    ])
  end

  def ops, do: list_of(op(), min_length: 1, max_length: 40)

  # -- a stream that keeps no promises ---------------------------------------

  def junk do
    one_of([
      constant(nil),
      integer(),
      text(),
      list_of(one_of([integer(), text(), constant(%{"path" => "/a"})]), max_length: 2),
      constant(%{"title" => "T", "kind" => "edit", "content" => "x"})
    ])
  end

  def payload do
    keys = ~w(text toolCallId status content locations entries tool_call options decision output kind update)
    map_of(member_of(keys), junk(), max_length: 4)
  end

  @types ~w(output_text_delta thinking_delta output_text_final tool_call tool_result command_output_delta
            file_change plan_updated usage approval_requested approval_resolved turn_completed turn_failed
            turn_interrupted session_failed session_closed provider_event unknown_type)a

  def hostile_op do
    frequency([
      {8,
       tuple(
         {constant(:event), member_of(@types), payload(), member_of(["t1", "t2", nil]),
          member_of(["r1", "r2", nil])}
       )},
      {1, constant({:restart})}
    ])
  end

  def hostile_ops, do: list_of(hostile_op(), min_length: 1, max_length: 25)
end

defmodule Spike.PropsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Jido.Harness.Event
  alias Spike.{Gen, Run}
  alias Stratta.Timeline

  @runs String.to_integer(System.get_env("RUNS", "300"))

  # GREEN_ONLY=1 leaves out what already fails on the unmodified module, so that a
  # failure under mutation is the mutant's.
  @red if System.get_env("GREEN_ONLY"),
         do: [:restart_leaves_nothing_open, :turn_end_closes_tools, :restart_notice_only_if_unfinished],
         else: []

  for {name, _} <- Run.invariants(), name not in @red do
    property "well-formed stream: #{name}" do
      check all(ops <- Gen.ops(), max_runs: @runs) do
        bad = Run.run(ops)
        refute Map.has_key?(bad, unquote(name)), inspect(bad[unquote(name)], pretty: true, limit: :infinity)
      end
    end
  end

  # Classified apart: these say what happens when the agent's stream is not well-formed.
  @tag :hostile
  @tag skip: System.get_env("GREEN_ONLY") != nil
  property "hostile stream: folding an event never raises" do
    check all(ops <- Gen.hostile_ops(), max_runs: @runs) do
      Enum.reduce(ops, {Timeline.new(), 0}, fn
        {:restart}, {tl, n} ->
          {tl.items |> Run.roundtrip() |> Timeline.new() |> Timeline.close_dangling(), n}

        {:event, type, payload, turn, req}, {tl, n} ->
          e = Event.new!(type: type, provider: :demo, payload: payload, turn_id: turn, sequence: n + 1, request_id: req)
          {Timeline.apply_event(tl, e), n + 1}
      end)
    end
  end
end
