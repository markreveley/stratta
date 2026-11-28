# What should Stratta do with an event it cannot read?

**Date:** 2026-11-27

**Question.** A generated test found three lines where an event of the wrong shape makes the timeline code raise. Should that code ever raise? The operator has to say, and asked for the background from first principles.

**Sources read.** `core/lib/stratta/timeline.ex` and `core/lib/stratta/thread_server.ex` at `c387317`. `lib/jido_harness/session/transports/acp.ex` in Harness at `f810a4c`. The plans [event-log](../../plans/2026-11-26-event-log/event-log.md) and [adversarial-boundaries](../../plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md).

**Method caveat.** The raises were run, on `timeline.ex` by itself on Elixir 1.14.0, with events made by a generator. What follows a raise in a running daemon (section 4) was read from the code and from how OTP works, and was not run. No real agent was seen to send a malformed event.

---

## 1. The short answer

Today a malformed event ends the thread's process, and the operator sees a notice that does not say why. Nothing else is harmed. The recommendation is that the code that folds events should never raise: what it cannot read becomes a visible notice in the thread, and the rule "folding never raises" is checked by generated tests from then on. The strongest reason is in the future: if events are ever stored and folded again, one unreadable event would make its thread fail on every load.

## 2. The path an event takes

1. **The agent** is a separate program. It writes messages to Stratta as JSON: text, tool calls, plans, requests for permission.
2. **Harness** reads each message and turns it into an event with a type and a payload. For text it checks that the text is a string. For a tool call it passes the agent's message through as the payload, unchanged (read at `acp.ex` line 587).
3. **The thread's process** (`ThreadServer`) receives events in order and hands each to the timeline.
4. **The fold** (`Timeline.apply_event/2`) takes the timeline so far and one event, and returns the timeline with that event applied. It is a function with no side effects: same inputs, same result.
5. The new items are shown to every client and saved to disk a moment later.

Two words used below:

- **Raise.** In Elixir a function that meets something it cannot handle raises an error. If nothing catches it, the process it is running in dies.
- **Supervision.** Each thread is its own process under a supervisor. When one dies abnormally the supervisor starts a fresh one. Other threads are not touched. This is the usual Elixir design, often called "let it crash": do not write defensive code for the impossible; let the process die and restart clean.

## 3. What was found

From [the fold issue](../../issues/2026-11-27-timeline-fold.md), item 5. Three lines raise:

- command output whose text is not a string;
- a permission request whose description of the tool is not a map;
- a tool call whose list of locations is not a list of maps.

The fold assumes shapes that nothing has checked.

## 4. What a raise does today

Read, not run:

1. The thread's process dies in the middle of handling a batch of events. The events in that batch are lost.
2. On the way out it saves the items it had and closes the agent's session.
3. The supervisor starts a new process for the thread. It loads the saved items and has no session.
4. The thread shows "The previous session ended before this turn finished. Send a message to continue." The reason is in the daemon's log and nowhere the operator looks.

It cannot loop: a restarted thread has no session, so no more events arrive until the operator sends a message.

## 5. Who can cause it

- **An agent with a bug, or a dialect Harness maps loosely.** Stratta runs eleven kinds of agent, each with its own messages. This is the likely case.
- **An agent on purpose,** under the operator's working assumption that agents are adversarial. What it gains is the end of its own session, which it could have by exiting. It cannot reach another thread this way. So as an attack it is weak.

The cost is to the operator: a thread that stops for no stated reason, and a turn's work cut off.

## 6. The principle underneath

**"Let it crash" is for a fault in the program. A malformed message from outside is input.** A web server does not crash on a bad request; it answers that the request was bad. The fold stands at the same kind of boundary: everything in a payload was written by a program Stratta does not control.

A second principle applies only if the [event-log](../../plans/2026-11-26-event-log/event-log.md) plan's file of events is built. Then events are stored and folded again on every load. **A fold that is run again over stored input has to accept everything that was ever stored.** Otherwise one bad event makes the thread fail to load every time, and the restart that today gives a clean start would give the same crash.

## 7. The options

**A. Leave it.** A malformed event ends the session, as now.
- For: no code. The failure is loud in the log.
- Against: the operator is not told why. Unsafe once events are stored.

**B. The fold never raises.** A field of the wrong shape is treated as missing; the item is still made from what can be read. When something could not be read, the thread gets a notice saying the agent sent something Stratta could not read.
- For: the session survives. The operator sees it happened. "Folding never raises" is a rule a generated test can check on every push, and one is already written. Safe once events are stored.
- Against: more care in the fold, at each place a shape is assumed. A notice for every bad field could be noisy; one per turn would do.

**C. Catch it at the door.** `ThreadServer` catches any error from the fold, adds a notice, and carries on. The fold stays strict.
- For: one place to change.
- Against: it also catches Stratta's own mistakes in the fold and reports them as the agent's. It does nothing for the fold run at load time.

## 8. Recommendations

1. **Option B**, with one notice per turn at most.
2. **Keep the generated test that found this as a standing rule.** It fails today; it should pass after the fix and stay.
3. **Say in the notice which kind of event it was.** That is what makes the report useful to whoever maintains the agent's adapter.
4. Record the choice where the event-log plan can see it: that plan's file of events depends on it.
