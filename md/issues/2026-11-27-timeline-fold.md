# `Stratta.Timeline`: what a restart and a turn's end leave behind, and events that make the fold raise

| | |
|---|---|
| What was checked | `core/lib/stratta/timeline.ex`, by itself, against rules written as generated tests |
| Commit | `c387317` |
| How | Run: Elixir 1.14.0 on Erlang/OTP 25, beside a stand-in for `Jido.Harness.Event`, with StreamData and Jason compiled from git. The scripts are in [`spike/`](../analysis/2026-11-27-verification-design/spike/); `run.sh` runs them. Not run: the daemon, Harness, a real agent, or the versions Stratta requires |
| Rechecked | not yet |
| Reported | here only; no tracker entry |

Each sequence below is the shortest the machine found that breaks the rule, run again by
hand with `run.sh CHECKOUTS confirm`. A *restart* means what `ThreadServer.init/1` does
at line 77: the stored items go through JSON, `Timeline.new/1` and
`Timeline.close_dangling/1`.

None of these has been seen in a running daemon.

## 1. Every restart of an unfinished thread adds another warning

- **Location.** `close_dangling/1`, lines 123 to 153.
- **Expected.** A thread whose last turn never finished gets one notice saying so.
- **Observed.** `[message, restart, restart, restart]` gives one message and three
  copies of "The previous session ended before this turn finished. Send a message to
  continue." A turn counts as open when it has a message and no turn end. The function
  adds the notice and never adds a turn end, so the turn is still open at the next start.
- **Read, not run.** Whether the copies reach the disk depends on a save happening after
  the load. `ThreadServer` saves on a timer after any change and in `terminate/2`.
- **Status.** Open. A defect whatever is decided under item 2.

## 2. A tool call still open when its turn ends stays open

- **Location.** The three turn-end clauses of `reduce/3`, which close the turn's
  requests through `expire_pending_approvals/2` and leave its tool calls alone.
- **Expected.** For the operator to say. The background and the options are in
  [open tool calls](../analysis/2026-11-27-open-tool-calls/open-tool-calls.md).
- **Observed.** `[message, tool call, turn completed]` leaves the tool call `pending`
  for good. Both front ends print the status word: the app in
  `gui/lib/stratta_web/components.ex` line 91, the terminal client in
  `tui/lib/stratta/tui/render.ex` line 80, in the accent style it gives `pending` and
  `in_progress`.
- **Status.** Waiting on the operator's decision, a step in `next.md`.

## 3. A restart closes an open tool call in one case and not in another

- **Location.** `close_dangling/1`, line 133. The function returns the timeline
  unchanged unless a turn is open or some item has the status `pending`. It does not
  look for `in_progress`.
- **Expected.** The same treatment for a tool call left `pending` and one left
  `in_progress`.
- **Observed.** `[message, tool call, tool update in_progress, turn interrupted,
  restart]` leaves the tool call `in_progress` after the restart. With the tool call
  still `pending` instead, the restart marks it `interrupted` (item 4). An interrupt
  while a tool runs is the ordinary way to reach the first case.
- **Note.** This one needed 138 and 307 generated sequences to find in two runs, and a
  third run of 300 missed it. A rule checked with too few runs passes.
- **Status.** Open.

## 4. A restart can say a finished turn did not finish

- **Location.** `close_dangling/1`, lines 133 and 147 to 151.
- **Expected.** The warning only when a turn was left unfinished.
- **Observed.** `[message, tool call, turn completed, restart]` gives the tool call
  `interrupted`, which is reasonable, and then the warning that the previous session
  ended before the turn finished. The turn has a turn end with the status `completed`.
  The leftover `pending` tool call is what triggers the branch.
- **Status.** Open.

## 5. Folding an event raises on a payload of the wrong shape

- **Location.** Three lines:
  - 213, `:command_output_delta` whose `text` is not a string, once the turn has a tool
    call (`ArgumentError`);
  - 252, `:approval_requested` whose `tool_call` is not a map (`ArgumentError` or
    `FunctionClauseError`);
  - 345, `:tool_call` or `:tool_result` whose `locations` is not a list of maps
    (`FunctionClauseError`).
- **Expected.** For the operator to say: whether the fold may raise at all. The
  background and the options are in
  [events the fold cannot read](../analysis/2026-11-27-malformed-events/malformed-events.md).
- **Observed.** 30,000 short streams of events with payloads of the wrong shape, from
  `run.sh CHECKOUTS census`. Every raise fell on one of the three lines. The generator
  only makes the wrong shapes it was given, so other lines are not cleared.
- **Read, not run.** In Harness at `f810a4c`, `lib/jido_harness/session/transports/acp.ex`
  line 587 passes an agent's `tool_call` update through unchanged, so an agent can reach
  line 345. A raise in `ThreadServer.handle_info/2` (line 184) ends the thread's process;
  it restarts with no session and with the warning from item 1.
- **Status.** Waiting on the operator's decision, a step in `next.md`.

## 6. `cursor` is written and never read

- **Location.** The struct's default at line 25 and the update at line 163.
- **Expected.** A field that something reads, or no field.
- **Observed.** A search of `core/`, `gui/` and `tui/` finds no reader. `ThreadServer`
  starts its follower with a fixed `cursor: 0` and keeps its own position. Two mutants
  that change line 163 survive every test (see
  [the tests](2026-11-27-timeline-tests.md)).
- **Status.** Open. Small.
