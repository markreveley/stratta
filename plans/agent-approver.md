---
type: plan
kind: exploration
status: proposed
created: 2026-11-25
---

# An agent as an approver

## Summary

A rule can answer a request by matching its shape. It cannot answer a request that needs
the proposal read: *is this edit actually equivalent*, *does this command do what it says*.
This plan lets a second thread answer such a request — a reviewer, given the proposal and
its grounds, returning allow or deny with a reason — under a grant that is strictly weaker
than the operator's, with every answer recorded and reversible.

It needs [delegated authority](delegated-authority.md) first.

## Why this exists

Kind: **exploration**, and not scheduled.

No request in attended use has been a burden to answer. The operator's report on
2026-11-26 is that requests from coding agents have been appropriate and informative.
This plan argues from principle, that a rule cannot read a proposal, and no moment in use
prompted it.

It is kept for the case that would change this: unattended work, with many threads at
once or a daemon working while the operator is away.

One constraint from the identity layer it would most likely run on. Version 1 of
IdentiKey's capability spec binds a grant to one key, and a hop cannot remove the
binding. Under that verifier a reviewer cannot hold a grant of its own: it runs under the
operator's key with the narrowing enforced by what Stratta accepts, or it waits for a
later version of the spec. Read on 2026-11-23, not run.

## Why it needs the authority plan first

A reviewer that can answer anything is not a reviewer, it is the removal of the operator
from the loop with no record of what was removed. The grant is what makes the difference
between "approvals are now automatic" and "reads and equivalent-edit checks are delegated
to a reviewer, for this project, for the next hour, and here is every answer it gave".

## Design

- A reviewer is an ordinary Stratta thread, in the same project, usually in its own
  worktree, visible in the sidebar as a child of the thread it serves. Its work is a normal
  transcript the operator can read. Nothing about it is a hidden side channel.
- [Policy](policy-as-actions.md) decides which requests are **referable** — a third answer
  beside allow, deny and ask. A referable request goes to the reviewer; anything else
  behaves as it does today.
- The reviewer is given the proposal, the evidence event ids, and the thread's
  [claims](claim-graph.md) where they exist. It answers with a decision and a reason.
- Its answer is written as a [decision record](decision-records.md) naming the reviewer's
  thread and its grant, with its reason stored. The operator can reverse it; the reversal
  is its own record, and reversals are what the rework measure in
  [traces and measures](decision-telemetry.md) counts.
- A referred request that times out is not allowed. It becomes an ordinary ask.

## Safety

- **Off by default**, per project, with an expiry. A grant with no expiry is not offered.
- **Never its own.** A reviewer may not answer a request raised by itself, by its own
  session, or by any thread it is a child of. The caller checks already planned for the
  socket apply, and the grant must also be scoped so that the reviewer's own requests fall
  outside it.
- **Strictly weaker.** The reviewer's grant can only cover categories the operator
  explicitly delegated. Shell commands, anything outside the working folder, and anything
  touching the data directory are not delegable in the first version.
- **Disagreement escalates.** Where a rule would allow and the reviewer denies, the denial
  stands. Where a rule would deny, the reviewer is not consulted.
- **Visible.** `stratta decisions --by reviewer` and a line on the dashboard showing how
  many answers were given on the operator's behalf since the grant was issued. An
  automatic answer nobody can see is the failure mode to design against.

## Phases

### Phase 0: referral without a reviewer (small)

Add the referable outcome to policy and route it to a stub that always answers "ask". No
agent involved. This makes the plumbing testable, and confirms a referred request behaves
exactly like an ordinary one when nothing answers it.

### Phase 1: the reviewer thread (medium)

Spawn a reviewer as a child thread, hand it the proposal and the evidence, parse its
answer, record it, time it out to "ask". One delegable category to start: reads outside
the ones a plain rule can already allow.

### Phase 2: reasons, reversal and visibility (small to medium)

The reason stored and shown, reversal as its own record, the dashboard line, and
`stratta decisions --by`.

### Phase 3: equivalent-edit review (medium)

The second delegable category, and the first one that needs the reviewer to read a diff
rather than a path. Done when the operator is willing to leave it on for a day on a real
project.

## Not in scope

- A reviewer that edits, commits or ships. It answers and it explains; it does not act.
- Several reviewers voting. Worth considering only if one reviewer turns out to be
  unreliable in a way a second would catch.
- Reviewing a pane thread's requests. Possible once pane-thread requests carry the same
  record, but the proposal a hook provides is thinner and the first version should not
  depend on it.

## Open questions

- Does the reviewer get a fresh thread per request, or one long-lived thread per project
  that reviews many? Fresh is cleaner and more expensive; long-lived accumulates context
  that may be the point.
- Which model reviews? The cheapest honest answer is "a different one from the proposer",
  and that is a setting, not a default to guess at.
- Should a reviewer see the operator's past decisions on similar requests? That is a
  context question and belongs to [context as a query](context-queries.md), but it is the
  obvious first thing to want.

## Findings

*Empty until Phase 0 runs.*
