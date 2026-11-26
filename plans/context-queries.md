---
type: plan
kind: experiment
status: proposed
created: 2026-11-25
---

# Context as a recorded query

## Summary

If [claims](claim-graph.md) exist, then the material a thread is started or continued with
can be assembled from them — the claims it depends on — rather than from a transcript that
is trimmed when it gets long. This plan does that in the one place Stratta genuinely
controls, records which claims went in, and measures whether it beats the transcript.

## Why this exists

Kind: **experiment**.

One number decides it: does a hand-off seeded with claims beat one seeded with the
transcript at equal size? No use of Stratta has shown the transcript seed to be a
problem. The question is the operator's, from work on claim graphs, and the plan is
built to answer it either way.

## The constraint that shapes the whole plan

**Stratta does not own an agent's context window.** Each agent CLI assembles its own
prompt, and nothing here changes that. What Stratta controls is narrow and specific:

- the prompt text it sends;
- the material a hand-off is seeded with, when a thread continues under a different agent
  in the same folder;
- files it writes into the working folder, which an agent may or may not read;
- a resumed conversation, which belongs to the agent and is opaque.

So the lever is the **seed**, and hand-off is where the whole experiment can be run end to
end: the same work, continued twice from the same point, once seeded with a transcript and
once with a claim subgraph. Anything beyond that is advice to an agent, not control over
it, and this plan should not pretend otherwise.

## Design

- **A query, not a dump.** Continuing or handing off a thread assembles a seed from: the
  claims this thread committed to, their grounds, and the promoted claims they depend on.
  Written as a query over the collection, with a size budget.
- **The query is recorded.** Every seed stores which claim ids went into it and which were
  left out for budget. This is the part that makes the rest measurable: when an agent gets
  something wrong, *the claim was not in the seed* and *the claim was in the seed and
  ignored* become different findings with different fixes. They are indistinguishable
  today, for anyone.
- **What was in the window** is shown on the thread as a collapsed card listing the claims
  the seed carried, each one clickable to its grounds.
- **Retraction reaches forward.** Withdrawing a claim lists every live thread whose seed
  carried it. A collection built after the fact can only tell the operator about finished
  threads; this is the one thing being in-band buys that nothing else does.

## Measuring it

The operator already keeps an evals harness, in artifact-dag's `evals/`, that compares prose against claim graphs as
material for a model. This plan's job is to feed it real seeds from real threads rather
than constructed ones, and to answer one question: **does a hand-off seeded with a claim
subgraph do better than one seeded with the transcript, at equal size?**

Report the comparison with the budget stated, so that the two seeds can be compared at
equal size.

## Phases

### Phase 1: record what the seed carried (small)

Before changing how seeds are built, store what today's hand-off seed contains. A baseline,
and useful on its own: hand-off currently seeds a transcript and nothing says how much of
it fitted.

### Phase 2: a seed from claims (medium; needs claims Phase 2)

Assemble a hand-off seed from the thread's claims and their grounds, under a size budget,
with the query and its exclusions recorded. Both seed kinds available, chosen per hand-off.

### Phase 3: the comparison (medium; mostly measurement)

Run the same hand-off both ways on a set of real threads through the operator's harness.
Write the result into this plan whichever way it goes.

### Phase 4: the window card and retraction (small to medium)

The collapsed card on the thread; `stratta claims --used-by` and the list of live threads
whose seed carried a withdrawn claim.

### Phase 5: starting a thread from a query (medium; only if Phase 3 is positive)

`stratta new --with <query>`: a new thread's opening prompt assembled from promoted claims
rather than typed.

## Not in scope

- Anything that reaches inside an agent's own prompt assembly or its resumed conversation.
- Similarity search. The retrieval here is over typed edges; if the answer turns out to
  need embeddings, that is a finding and a different plan.
- Automatic retraction. Withdrawal is an act, and its consequences are shown, not applied.

## Open questions

- A size budget in tokens needs a tokeniser per model, which Stratta does not have. Is
  budgeting in bytes honest enough for the comparison to mean anything?
- Does a seed built from claims need the diffs, or do the claims and their file paths
  carry enough?
- If Phase 3 is negative, is the claim graph still worth keeping for the audit and
  retraction properties alone? Worth deciding before the measurement, so the answer is not
  argued backwards from it.

## Findings

*Empty until Phase 1 runs.*
