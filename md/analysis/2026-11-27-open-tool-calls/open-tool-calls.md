# What should a thread show for a tool call that never finished?

**Date:** 2026-11-27

**Question.** A generated test found that a tool call still open when its turn ends stays open for good. Is that a defect? The operator has to say what should happen, and asked for the background from first principles.

**Sources read.** `core/lib/stratta/timeline.ex`, `core/lib/stratta/thread_server.ex`, `gui/lib/stratta_web/components.ex` and `tui/lib/stratta/tui/render.ex` at `c387317`. `lib/jido_harness/session/transports/acp.ex` in Harness at `f810a4c`. The plans [event-log](../../plans/2026-11-26-event-log/event-log.md) and [decision-records](../../plans/2026-11-25-decision-records/decision-records.md).

**Method caveat.** The behaviour in section 4 was run, on `timeline.ex` by itself on Elixir 1.14.0. Nothing was run in a daemon or with a real agent. How often a real agent leaves a tool call open is not known: section 3 lists the ways it can happen, from reading.

---

## 1. The short answer

It is a defect in what the thread says, and the fix is a choice between three options. The recommendation is the second: when a turn ends, close its open tool calls and record that Stratta closed them, not the agent. Whichever is chosen, a restart should apply the same rule, once.

## 2. The parts

- **A thread's timeline** is a list of items: a message from the operator, text from the agent, a tool call, a plan, a permission request, the end of a turn, a notice.
- **A turn** is one piece of work by the agent: it starts when the operator sends a message and ends when the agent stops. Harness reports the end as completed, failed or interrupted, and the timeline gets a turn-end item.
- **A tool call** is the agent doing something: reading a file, editing one, running a command. The agent reports it, and then reports updates to it. Each report carries a status. The usual life is `pending`, then `in_progress`, then `completed` or `failed`.
- **The status on a tool call item is the agent's last report.** Stratta copies it. Stratta does not run the tool and does not know by itself whether it finished.
- **A permission request** has a status too, and it is Stratta's own: `pending` until the operator answers. When a turn ends, Stratta marks that turn's unanswered requests `expired`. It does nothing like that for tool calls.

So there are two kinds of status in a thread. One is something Stratta knows (a request). The other is something an agent said (a tool call).

## 3. How a tool call comes to be open after its turn

Read, not observed:

- **The operator interrupts** while a tool is running. The agent stops and may send no last update. This is ordinary use.
- **The agent fails or its process dies** in the middle of a tool call.
- **The agent ends its turn without closing the call.** A careless agent, or one whose reports Harness maps differently. Stratta runs eleven kinds of agent.
- **A permission is denied.** Whether the agent then reports the tool call as failed is up to the agent.

## 4. What happens today

Run on the module by itself; the sequences are in [the fold issue](../../issues/2026-11-27-timeline-fold.md).

- **At the end of the turn:** nothing. The tool call keeps its last status, `pending` or `in_progress`, under a turn that says it completed or was interrupted.
- **In both front ends** the status word is printed as it is. The terminal client gives `pending` and `in_progress` one accent style, apart from `completed` and `failed`.
- **At the next restart of the daemon,** one of three things, depending on details that should not matter:
  - the call was `pending`: it becomes `interrupted`, and the thread gets a warning that the turn did not finish, though it did;
  - the call was `in_progress` and no turn is open: nothing changes, and it says `in_progress` for good;
  - the call was `in_progress` and a turn is open: it becomes `interrupted`.

## 5. Why it matters

- **A status is a claim about now.** "In progress" under a turn that ended is false, and the operator reads it.
- **Other plans read these items.** A decision record points at timeline items as evidence. A claim built from a thread would carry the false status with it.
- **The timeline is the only record.** Events are not kept; only the items made from them are. So if Stratta overwrites the agent's last report, what the agent said is gone. The event-log plan would change that: with the events kept, the timeline becomes a view that can be rebuilt, and overwriting costs nothing.

That last point is the principle underneath the choice: **is an item a record of what the agent said, or Stratta's statement of what is true?** Today it is both at once, and this is where they disagree.

## 6. The options

**A. Leave the item as the agent left it.** The timeline is a faithful record. Fix only the restart, so that it treats every case the same way.
- For: nothing is invented. Smallest change.
- Against: the thread goes on saying something is in progress when it is not. Every reader has to know to distrust it.

**B. Close it when the turn ends, and say who closed it.** When a turn ends, each of its tool calls that is still `pending` or `in_progress` gets a final status, and a field recording that Stratta set it at the end of the turn and what the agent's last report was.
- For: the thread says what is true, and what the agent said is still there. One rule covers the end of a turn and a restart. It matches what already happens to requests.
- Against: Stratta is asserting something it inferred. A new field on an item, which every stored thread lacks and every reader must tolerate.
- A detail to settle: one word for all cases (`interrupted` is already used by the restart), or a word that follows how the turn ended.

**C. Store the item as it is, and work out the display.** The item is untouched. Whatever shows it treats an open tool call under an ended turn as not finished.
- For: the record is faithful and the display is true.
- Against: every reader has to apply the rule: the app, the terminal client, each view the composed-surfaces plan adds, and anything that reads the stored file. Doing it once in the API's snapshot helps, and leaves the file on disk saying something else.

## 7. Recommendations

1. **Option B**, with the agent's last report kept on the item.
2. **One rule in one place**, used at the end of a turn and at a restart, and applying only once. That closes items 1, 3 and 4 of the fold issue as well as item 2.
3. **Write the rule down and check it with the generated tests** that found this. Two of the fourteen rules in the spike are this rule and are failing now.
4. If the event-log plan's file of events is built, revisit: at that point B loses its one cost.
