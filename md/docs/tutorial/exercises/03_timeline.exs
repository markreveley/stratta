# Lab 3: state as a fold over events          (tutorial sections 11, 12 and 26)
#
# A miniature of Stratta.Timeline: a pure reducer from events to chat items.
# No process, no clock, no disk. The last function, evidence/2, is the
# question Phase 0 of the decision-records plan asks of the real timeline.
#
# Run:  elixir exercises/03_timeline.exs

ExUnit.start()

defmodule Lab.Timeline do
  defstruct items: [], next_id: 1, approval_seq: 0

  def new, do: %__MODULE__{}

  @doc "The whole state is the fold of the event list."
  def fold(events), do: Enum.reduce(events, new(), &apply_event(&2, &1))

  @doc "The n-th request's letter: a..z, then aa, ab, ..."
  def label(_n), do: raise("not implemented")

  @doc "Folds one event into the timeline. Unknown events change nothing."
  def apply_event(_tl, _event), do: raise("not implemented")

  @doc "Labels of the requests still waiting, oldest first."
  def pending(_tl), do: raise("not implemented")

  @doc "The ids of the items in the same turn that come before the request."
  def evidence(_tl, _label), do: raise("not implemented")
end

defmodule Lab.TimelineTest do
  use ExUnit.Case

  alias Lab.Timeline

  @events [
    {:user, "t1", "add a greeting file"},
    {:text, "t1", "I will "},
    {:text, "t1", "create hello.txt."},
    {:tool_call, "t1", "c1", "list files"},
    {:tool_result, "c1", "README.md"},
    {:approval_requested, "t1", "r1", "write hello.txt"},
    {:approval_resolved, "r1", :approve},
    {:turn_completed, "t1"},
    {:user, "t2", "now commit it"},
    {:tool_call, "t2", "c2", "git status"},
    {:approval_requested, "t2", "r2", "run git commit"}
  ]

  test "streamed chunks become one assistant item" do
    tl = Timeline.fold(Enum.take(@events, 3))
    assert [%{kind: :user}, %{kind: :assistant, text: "I will create hello.txt."}] = tl.items
  end

  test "labels run a..z, then aa" do
    assert Enum.map([0, 1, 25, 26, 27, 51, 52, 701, 702], &Timeline.label/1) ==
             ["a", "b", "z", "aa", "ab", "az", "ba", "zz", "aaa"]
  end

  test "a label is never reused, across turns" do
    tl = Timeline.fold(@events)
    assert for(%{kind: :approval} = item <- tl.items, do: {item.label, item.status}) ==
             [{"a", :approved}, {"b", :pending}]

    assert Timeline.pending(tl) == ["b"]
  end

  test "folding in two pieces gives the same state as folding at once" do
    whole = Timeline.fold(@events)

    for k <- 0..length(@events) do
      {first, rest} = Enum.split(@events, k)
      resumed = Enum.reduce(rest, Timeline.fold(first), &Timeline.apply_event(&2, &1))
      assert resumed == whole
    end
  end

  test "events the timeline does not know are ignored" do
    assert Timeline.fold([{:usage, 120}, {:user, "t1", "hi"}]) == Timeline.fold([{:user, "t1", "hi"}])
  end

  test "a turn that ends takes its unanswered requests with it" do
    tl = Timeline.fold(@events ++ [{:turn_completed, "t2"}])
    assert Timeline.pending(tl) == []
    assert %{status: :expired} = Enum.find(tl.items, &(&1[:label] == "b"))
  end

  test "evidence is the ids of what came before the request, in its own turn" do
    tl = Timeline.fold(@events)
    kinds = fn ids -> for %{id: id, kind: kind} <- tl.items, id in ids, do: kind end

    assert kinds.(Timeline.evidence(tl, "a")) == [:user, :assistant, :tool]
    assert kinds.(Timeline.evidence(tl, "b")) == [:user, :tool]
    assert Timeline.evidence(tl, "zz") == []
  end
end
