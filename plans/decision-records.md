---
type: plan
kind: need
status: proposed
created: 2026-11-25
---

# Decisions as records

## Summary

Every permission request Stratta answers is a decision: something was proposed, something
was known at the time, and somebody or some rule said yes or no. Today that decision
leaves a line in the timeline and nothing else. This plan makes the decision itself an
addressable record, written when the request is answered, out of what the daemon already
holds.

It is first because four later plans need the same record and none of them should invent
its own: [policy as actions](policy-as-actions.md) records which rule fired,
[traces and measures](decision-telemetry.md) measures decisions,
[claims](claim-graph.md) hangs a claim on the moment of commitment, and
[delegated authority](delegated-authority.md) records under whose authority the answer was
given. Build it once, and build it so that it is worth having on its own: "why was `2a`
approved, and how long did it wait?" is a question that cannot be answered today
without reading a transcript.

## Why this exists

Kind: **need**, and a source of evidence for the other plans.

A fact in the code: nothing records when a request arrived, how long it waited, or who
answered it. Policy, the reviewer and much of the authority work assume that answering
requests is a burden. The waiting time this plan records is one piece of evidence on
that, beside the operator's own sense of it.

## What happens today

- A permission request arrives as a provider event, is held by `ThreadServer`, and is
  named by slot and letter (`2a`).
- Answering it sends the decision back through the `Jido.Harness` session. The request and
  the answer both appear in `Stratta.Timeline` as events.
- The events that led up to the request — the tool calls, their results, the files the
  agent read — are in the same timeline, in order.
- Nothing joins those three things together. The join is done by eye.

## Design

A record written when a request is answered, holding only what the daemon can derive
itself:

- **the request** — thread, slot name, the agent's own statement of it (tool, arguments,
  and the diff where there is one), as it was shown to whoever answered;
- **the answer** — allow or deny, and which option where the agent offered several;
- **who answered** — the client that sent it, identified the way the socket already
  identifies callers, or the rule that answered it once there are rules;
- **two times** — when the request arrived, and when it was answered. Nothing records
  the gap today;
- **the evidence** — the ids of the timeline events between the start of the turn and the
  request. Ids, not copies: nothing is duplicated and nothing is summarised;
- **the ground** — base commit, working folder, worktree branch, model and agent in use.

Stored in `~/.stratta` beside the transcript, append-only. Read back through
`decisions.list` and `decisions.get` on the socket API, `stratta decisions [slot]` in the
client, and a panel on the thread in the app.

**No model writes any part of this record.** Every field is either stated by the agent's
own protocol or observed by the daemon. That property is what makes the later plans
something other than a scrape, so it is a rule and not a default.

## Phases

### Phase 0: what can be derived (small)

Take one recorded demo-agent thread that contains an edit approval, and write out by hand
the record the daemon could have produced from it. The question: is the evidence slot
derivable from the timeline as it stands, or does the turn need instrumenting to know
which events belong to which request? Everything else in this plan is easy; this is the
part that decides its shape. Write the answer into Findings.

### Phase 1: the record (small to medium)

- `Stratta.Decision` and its store; written on every answered request in a headless
  thread, including requests answered automatically if any already are.
- Both times, and the ground.
- `decisions.list`, `decisions.get`, `stratta decisions`.
- Tests against the demo agent: an approval, a denial, and a request answered after the
  daemon restarts.

### Phase 2: the evidence (medium)

- Event ids attached, as Phase 0 directs.
- The app shows a request together with what preceded it, and the diff panel can be
  reached from a past decision.

### Phase 3: requests from a pane (small; after [pane threads](pane-threads-via-hooks.md) Phase 1)

- A request that arrived through an agent's hook produces the same record, with the hook
  payload as the request. One record type covers both kinds of thread, which is the reason
  to do this plan after that one's Phase 1 rather than before it.

## Not in scope

- Rules, claims, authority or measures. Each has its own plan, and each reads this record
  rather than extending it.
- Anything written by a model.
- Decisions other than permission requests. Interrupts, hand-offs and ships are candidates
  later; a request is the one that already pauses and already has an answerer.

## Open questions

- One log per thread, or one per data directory with a thread index?
- Does a record outlive the thread it belongs to?
- Is the agent's own statement of a request stable enough to store verbatim, or does it
  need normalising per provider?

## Findings

*To be filled in by Phase 0.*
