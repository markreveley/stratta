---
type: plan
kind: need
status: proposed
created: 2026-11-26
---

# Ids that survive a restart, and a log of events

## Summary

Two facts about how a thread's history is kept bear on every plan that points at a moment
in a thread.

1. **A timeline item's id was not stable.** Ids were taken from a counter that belongs to
   the running virtual machine and starts again at 1 each time it starts. A thread that
   was reloaded and then continued gave new items ids that older items already had, and
   an update addressed to an id changed every item that had it. This was run, not only
   read; the output is below. Phase 1 is built and ends it: ids are counted per thread.
2. **The timeline is a projection, and nothing else is kept.** An item changes in place
   as later events arrive, and the events themselves are discarded once folded. So an id
   that is recorded as evidence for a decision can come to point at content that did not
   exist when the decision was made.

Phase 1 fixed the first. The remaining phases propose a per-thread,
append-only file of events with a number that never repeats within the thread. That part
is a proposed answer to the question Phase 0 of
[decisions as records](decision-records.md) asks, and is the operator's to take or leave
once that phase has been done.

## Why this exists

Kind: **need** for Phase 1, which is built. Phases 2 to 4 are a proposal that another
plan's finding decides.

A fact in the code, reproduced by running `Stratta.Timeline` across two lifetimes of the
virtual machine (see *What was run*). Whether it was met in use is not known: it needed
the daemon to restart and an existing thread to go on, which is what the README's
"pick up later" describes. Where it happened it would look like a tool call's title and
status appearing on an older message, or two rows of a thread's page behaving as one. A
thread that was damaged that way stays as it is: Phase 1 gives every item its own id on
load and cannot tell which fields an item should not have.

The suite did not see it. Its reload test (`rebuilds indexes from persisted items` in
`core/test/timeline_test.exs`) reloads inside one virtual machine, where the old counter
kept rising. Two tests added with Phase 1 fail against the old code and pass against the
new.

The second fact is not a defect today, because nothing stores an item's id outside the
thread it belongs to. It becomes one when [decision records](decision-records.md) Phase 2
stores ids as evidence, and [claims](claim-graph.md),
[context queries](context-queries.md) and
[context for each request](per-request-context.md) all store ids after it. Changing how
ids work is cheap now and is not once those exist.

## What happens today

Checked in the code after Phase 1:

- `Stratta.Timeline` counts its own items (`item_seq`). `push_with_id/2` makes an id as
  `"i"` followed by the next number.
- `Timeline.new/1`, which builds a timeline from stored items, carries the count on from
  the highest stored id, the way it restores the next request letter
  (`next_approval_seq/1`). A stored item with no id, or with the id of an earlier item,
  is given the next number.
- `update_item/3` applies its change to every item whose id matches, which is now one
  item.
- A tool item is changed in place when its result arrives (`merge_tool/2`), text items
  grow while a reply streams, and `close_dangling/1` rewrites statuses when a thread is
  loaded.
- No event is kept. `Stratta.ThreadServer` folds each event from `Jido.Harness` into the
  timeline and saves the items, the whole file each time, after a 400 millisecond pause.
  Harness numbers events within one session, and a session does not survive a restart.
- Item ids are used by the timeline's own indexes and as element ids on the thread's
  page in the app (`"item-" <> item["id"]`), which draws one thread's items at a time. A
  search of `core/`, `gui/` and `tui/` found no other place that stores one.
- Harness at `f810a4c` has a `Jido.Harness.ReplayStore` with a file journal. Read, not
  run. Its cursors belong to one run or session, its retention is bounded, and its guide
  says the files do not restore a provider's execution. Stratta's lock file names an
  earlier Harness commit, `891e09b`.

## What was run

Everything here ran on Elixir 1.14.0 with Erlang/OTP 25, which is older than Stratta
requires, with only `core/lib/stratta/timeline.ex` loaded beside a stand-in for the
`Jido.Harness.Event` struct. Stratta itself was not run, and neither was its suite.

**Before Phase 1**, on 2026-11-26, with the module as it stood at `3782faf`.

A first run of the virtual machine built a timeline of a user message, a tool call and a
permission request, and wrote the items to a file. A second run loaded them with
`Timeline.new/1` and folded in one new tool call and its result.

```
$ elixir -r stub.exs -r core/lib/stratta/timeline.ex run1.exs items.bin
run 1 saved: i1=user, i2=tool, i3=approval

$ elixir -r stub.exs -r core/lib/stratta/timeline.ex run2.exs items.bin
run 2 items: i1=user, i2=tool, i3=approval, i1=tool
repeated ids: ["i1"]
user message, as loaded:     %{"id" => "i1", "kind" => "user", "text" => "add a greeting file"}
user message, after the run: %{"id" => "i1", "kind" => "user", "status" => "completed", "text" => "add a greeting file", "title" => "Run mix test", "tool_kind" => "execute"}
```

The new tool call took the id of the user's message, and the tool's result was then
written into both.

**After Phase 1**, on 2026-11-27, the same two runs:

```
$ elixir -r stub.exs -r core/lib/stratta/timeline.ex run2.exs items.bin
run 2 items: i1=user, i2=tool, i3=approval, i4=tool
repeated ids: []
user message, as loaded:     %{"id" => "i1", "kind" => "user", "text" => "add a greeting file"}
user message, after the run: %{"id" => "i1", "kind" => "user", "text" => "add a greeting file"}
```

And `core/test/timeline_test.exs` by itself, with Jason 1.4.5 compiled from its
repository and the same stand-in: 10 tests, 0 failures. Against the module as it was
before, the two new tests fail.

The two scripts, the stand-in and the transcript are kept with the tutorial on this
repository (`markreveley/tutorials`, `beam/stratta-architecture-tut`), where
`scripts/check_timeline_ids.sh` runs them against a checkout.

## Design

### 1. An id is counted per thread and restored on load

Built in Phase 1. The timeline keeps a count of its own items, restored by
`Timeline.new/1` from the highest number among the stored ids, the way the request
letter already is. An id then means one item for as long as the thread exists. Ids stay
short and stay in order.

Ids are unique within a thread and not across threads. A reference from outside a thread
is the pair of thread id and item id.

A stored timeline may already hold repeats. On load, an item whose id an earlier item has
is given the next number, and so is an item with no id. Nothing outside the thread refers
to those ids yet, which is why this is safe to do now.

Two other schemes were considered. A random or time-ordered identifier is unique
everywhere and needs no count, at the price of length and of an order that can be read.
An id taken from the log in Design 2 (the number of the event that created the item) is
exact, and needs the log. The count does not get in the way of either later.

### 2. A file of events per thread, appended and never rewritten

`threads/<id>.events.jsonl`, one line per event, written before the event is folded:

- `n`: a number that starts at 1 for the thread and is never reused;
- the time;
- for an event from an agent: the Harness session, its sequence number within that
  session, the turn, the type and the payload;
- for an event of Stratta's own: a message sent, an answer given and by whom, an
  interrupt, a hand-off, a notice.

With Stratta's own events included, the file is the whole input of the fold, and the
timeline is what it has always been: the folded state, saved so that loading is fast.

What it would give:

- **Evidence that cannot change.** A decision's evidence is a range of `n`. What was
  known at the time is a prefix of the file.
- **A timeline that can be rebuilt.** When the fold changes, for instance to keep a
  field it used to drop, old threads can be folded again.
- **Nothing lost between an event and the save.** The snapshot records the last `n` it
  holds, and loading folds whatever the file has beyond it. That is another route to
  what the second test in step 19 of `next.md` checks.
- **One thing to point at** for decision records, claims, the record of what a seed or
  an assembled prompt carried, and spans made after the fact.

What it would cost:

- **Size.** A streamed reply is many small events. Whether to write each one or to join
  them is an open question, and Phase 2 exists to look at real files before anything
  reads them.
- **A second thing to keep true.** The snapshot and the file can disagree after a crash,
  and loading has to say which wins.
- **More of what the agent said, kept for longer.** The file holds every event,
  including ones the timeline folds away. It is deleted with the thread.

### 3. What a reference looks like

Inside a thread: an item id for something on the screen, or `n` for a moment. Outside:
the thread id with either. [Decision records](decision-records.md) Phase 0 is where the
choice between them for the evidence slot is made.

## Phases

### Phase 1: ids (built)

- The count in `Stratta.Timeline`, restored on load; the repair for stored repeats and
  for items with no id.
- Two tests in `core/test/timeline_test.exs`: a timeline built from stored items goes on
  after the highest stored number and a tool's result reaches only the new item; a
  stored timeline with a repeated or missing id loads with every id distinct.
- The thread's page in the app needs nothing: it draws one thread's items at a time, so
  ids that are unique within a thread are enough for its element ids. Read, not looked
  at in a browser.

Still to do: run `mix test` in `core/` on Elixir 1.19 with Erlang/OTP 28. It is in step 1
of `next.md`.

### Phase 2: the file, written and not yet read (small to medium)

- Append on arrival, with `n`, for agent events and Stratta's own.
- `stratta events <thread>` prints it. Nothing uses it for state.
- A note in Findings on how large the files are for some real threads and what they are
  mostly made of.

### Phase 3: loading from the snapshot and what follows it (medium)

- The snapshot records its last `n`; loading folds the rest of the file.
- A test: an event that arrives inside the save pause survives the daemon stopping.

### Phase 4: folding a thread again (small)

- Rebuild a timeline from its file. A test that the rebuilt timeline equals the stored
  one for threads run with the demo agent.

Phases 2 to 4 are written in the order they depend on each other; whether and when to do
them is the operator's call, and [decision records](decision-records.md) Phase 0 is the
first finding that bears on it.

## Not in scope

- Replacing the timeline. The snapshot stays; the file is what it is folded from.
- A log across threads, or a database.
- Sending the file anywhere.

## Open questions

- One line for each piece of a streamed reply, or one line for the whole?
- Is Harness's replay journal a possible store for this, or a second copy of part of it?
- Are tool call ids unique across the sessions of one thread, for each agent?
  `Timeline.new/1` rebuilds its index of tool calls from every stored item, and the id
  used when an agent sends none is `tool-` followed by the session's sequence number,
  which starts again with each session. Read, not run. The demo agent uses random ids.
- [Decision records](decision-records.md) asks whether to keep one log per thread or one
  per data directory. This plan assumes per thread. If that plan decides otherwise, this
  one follows it.

## Findings

- 2026-11-26: the repeat was reproduced, and a per-thread count was tried in a copy of
  the module. Both are under *What was run*.
- 2026-11-27: Phase 1 built. The restart check passes and the timeline's test file
  passes by itself, both on Elixir 1.14.0 with Erlang/OTP 25. The suite has not been run
  on the versions Stratta requires.
