---
type: plan
kind: need
---

# Adopt PropertyDamage's method

> Status: accepted · 2026-11-28 · from [borrowing its method whole](../../analysis/2026-11-27-borrowing-property-damage/borrowing-property-damage.md) and [the wider comparison](../../analysis/2026-11-27-methods-compared/methods-compared.md)

## Summary

The operator has decided that Stratta is built by the method PropertyDamage's repository
uses: behaviour specified in OpenSpec, a gate of commands every change must pass,
evidence rules, a second reader on each change, a pinned toolchain, and its library for
testing the daemon with generated sequences. This plan puts that in place in an order
that does first what needs no particular machine.

It replaces [the verification plan](../2026-11-27-verification/verification.md), which is
dropped.

## Why this exists

Kind: **need**. Facts in the repository at `644cb13`: nothing runs the tests
automatically; seeded bugs in the timeline pass every test about a third of the time; six
findings are open against the timeline
([the issues](../../issues/README.md)).

The method is the operator's decision, made on 28 November 2026 on three analyses. It was
not chosen from use: Stratta has not been used for real work, and PropertyDamage's
library has not been run here.

The order of the phases is the drafting agent's.

## Decisions

- **D1. The method is PropertyDamage's, whole.** Decided by the operator.
- **D2. OpenSpec sits at the root, as the tool ships.** `openspec/` holds the specs and
  the changes; the tool's skills are in `.agents/skills/`. It is a declared exception to
  repo-template's rule that documents live under `md/`. Recommended by the drafting
  agent when the operator asked; done in the same commit as this plan, and undone by
  deleting those folders.
- **D3. What plans and steps are for.** A plan in `md/plans/` and a step in `next.md` say
  what is next and why. An OpenSpec change is how one step's behaviour is specified and
  carried out. `state.md` and `next.md` stay the handoff.
- **D4. The method and the library are separate commitments.** The library is committed
  to after it has run against the daemon. If it does not fit, PropCheck or StreamData
  takes its place and nothing else here changes.
- **D5. The second reader.** Proposed, and the operator's to decide:
  [a second reader](../../analysis/2026-11-28-second-reader/second-reader.md).
- **D6. What the method lacks is added only on evidence**: checks held back from the
  coding session, seeded bugs in the code, a check of the front ends, review rules read
  from the base branch.

## Phases

### Phase 1: the gate

The evidence rules and the rule against piping a gate command are in `AGENTS.md` as of
this plan.

1. Done. A CI workflow runs, in each of the three apps, on the versions Stratta
   requires: two compiles with warnings as errors, the format check, the tests.
   [`md/docs/ci.md`](../../docs/ci.md) says what it runs and the reason for each choice;
   its control showed every check can fail; and its first run was the suite's first on
   those versions ([the report](../../tested/2026-11-28-0046-ci-first-run.md),
   [what it found](../../issues/2026-11-28-ci-first-run.md)).
2. `.tool-versions` with one exact Elixir and Erlang/OTP, once the operator has said
   what his machine runs.
3. `mix credo --strict` in the gate, after one run of it has been read.
4. From the first run: a `core/mix.lock`, so the three apps are tested against one
   version of Harness.
5. The tutorial's checks and the layout check as a fourth job. Proposed by the drafting
   agent; today agents run them by hand.

### Phase 2: the first spec

`openspec/specs/timeline/spec.md`, written from the fourteen rules the spike used
([its scripts](../../analysis/2026-11-27-verification-design/spike/)) and the operator's
answers on open tool calls and on events the fold cannot read. Then each open item in
[the fold issue](../../issues/2026-11-27-timeline-fold.md) is fixed as an OpenSpec
change, with its test shown failing first.

### Phase 3: the library

On the operator's machine, with him present: PropertyDamage through its interview skill
on the smallest subsystem with a rule he fears breaking. It is a step in `next.md` and
says yes or no.

### Phase 4: the second reader

Whatever D5 becomes.

### Phase 5: the other specs

One per domain, written when a step first touches that domain, not all at once.

## What would reopen this

From the comparison: the library is abandoned or keeps breaking its interface;
OpenSpec's ceremony costs one operator more than it returns; a defect met in use is of a
kind none of this could catch.
