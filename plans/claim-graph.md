---
type: plan
kind: experiment
status: proposed
created: 2026-11-25
---

# Claims recorded as the work happens

## Summary

Knowledge work done in a thread can be written down as claims with their grounds. Done
afterwards, by reading the transcript, this is a scrape: downstream, stale, and a second
job nobody wants at the end of a thread. Done at the moment a claim is committed to, it is
a record.

A permission request is such a moment, and Stratta already stops there, already holds the
proposal, and already has the events that led to it. This plan turns an answered request
into a claim node — structure from the daemon, one sentence from the agent — in a per-thread
collection, with a deliberate and small step for promoting a claim out of the thread into
a durable collection outside Stratta, artifact-dag first.

It is a pilot before it is a feature. The thing being tested is whether a graph that falls
out of a real thread, with no cleanup pass, is good for anything.

[Graphs](graphs.md) calls this, with decision records and the two context plans, the
record graph, to keep it apart from a graph of work across threads. A claim's evidence
ids need to hold across a restart, which they do since Phase 1 of
[ids and a log of events](event-log.md).

## Why this exists

Kind: **experiment**, on an interest brought to Stratta from outside it.

The operator works on claim graphs in artifact-dag and wants to know whether the moments
Stratta already stops at yield claims worth keeping. That is a question about claim
graphs, asked in Stratta because Stratta has the stopping points. No use of Stratta has
needed claims. Phase 0 is a gate and the plan ends there if the structure is of no
interest.

## Why this moment and not another

At a request the agent has to state what it intends before it may act. That statement is a
proposal with grounds behind it, and a person or a rule rules on it. Claim, grounds,
consequence, ruling: a node with provenance, available without anything being
reconstructed, because the daemon is holding all of it in order to draw the prompt.

Nothing else in a thread has that property. Prose in a reply is a claim with no ruling and
no commitment; a tool result is grounds with no claim.

## Design

A claim node, written when a [decision record](decision-records.md) is written:

- **Structure, from the daemon** — the decision's id, the thread, the proposal, the
  evidence event ids, the ruling and who gave it, the base commit, the files touched, and
  the parent claims (the claims whose evidence this one's evidence descends from, within
  the thread).
- **One sentence, from the agent** — what it takes itself to be claiming. Requested at the
  moment of the request and stored as text, with the agent and model that produced it
  named. It is the only part a model writes and it carries no edges.

Two tiers, because decision-grained claims are many and mostly dull:

- **Thread-local** — automatic, cheap, disposable, deleted with the thread. This is the
  working set and it is allowed to be boring.
- **Promoted** — a deliberate act, one claim at a time, from the app or
  `stratta claim promote <slot>`. Writes a node into a collection outside Stratta, in a
  plain-text node format with stable ids: artifact-dag's (`md/governance/SCHEMA.md`),
  which its validator `bin/dagcheck.js` can check.
  Stratta never writes into that collection except on promotion, and never edits what is
  there.

If everything is a claim then nothing is; promotion is the mechanism that keeps the second
tier worth reading.

## What it looks like

- A toggle on the thread: read it as a conversation, or read it as its claims.
- The request shows its ancestry: *this rests on these three findings*, each one clickable
  back to the events that are its grounds.
- A promoted claim shows where it went.

## Phases

### Phase 0: the pilot (small; writing and one script)

Take two or three real threads with approvals in them. Generate the nodes with structure
only — no sentence from any model. Check them against the operator's existing node format
and validator. Two questions, answered in Findings: does the structure alone hold up as a
graph, and are the parent links derivable within a thread or do they need a model's help?
If the structure alone is empty of interest, the commitment point is the wrong granularity
and this plan stops here, cheaply.

### Phase 1: thread-local claims (medium)

`Stratta.Claim` and a per-thread collection; written with every decision record; the
sentence requested from the agent where the protocol allows a side question, and left empty
where it does not. `claims.list`, `stratta claims`.

### Phase 2: ancestry, and the two views (medium)

Parent links within the thread, per Phase 0. The claims view in the app and the ancestry
line on the request.

### Phase 3: promotion (small to medium)

One claim at a time, into an external collection in a plain node format with stable ids,
with the decision record's id as the back reference. Nothing automatic.

### Phase 4: retraction, as far as Stratta can see it (small)

Marking a thread-local claim withdrawn, and listing the later claims in the same thread
whose grounds included it. Reaching across threads and into the external collection belongs
to [context as a query](context-queries.md).

## Not in scope

- Any claim about the world that does not come from a commitment inside a thread.
- Editing or reorganising the operator's external collection.
- A model summarising a thread into claims. That is the thing this plan exists to avoid.

## Open questions

- Can an agent be asked for one sentence mid-turn without disturbing the turn? For some
  providers the only honest answer may be to ask after the turn ends, which weakens the
  "at the moment of commitment" property for the sentence but not for the structure.
- Should a denial produce a claim? A refused proposal is a real finding and arguably the
  more valuable node.
- Node ids: derived from the decision id, or minted in the external collection's own
  scheme on promotion?

## Findings

*To be filled in by Phase 0.*
