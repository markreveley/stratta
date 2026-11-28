---
type: plan
kind: experiment
---

# Verification without reading the code

> Status: proposed · 2026-11-27 · from [the verification design](../../analysis/2026-11-27-verification-design/verification-design.md)

## Summary

The operator wants to build Stratta without reading its code by hand. This plan tries one
way of doing that and is built to be answered either way: the operator reads rules,
counterexamples and a report of what was exercised; machines check the code against the
rules; the checks are themselves checked; and the session that writes the code is not
what decides it passed.

The design is assembled from several sources and has not been shown to work as a whole
anywhere. The analysis this plan comes from says where each part is from and what would
count as evidence. So the phases are ordered to put first what is useful whatever the
answer is, and last what is a bet.

## Why this exists

Kind: **experiment**. The question: can one operator keep Stratta sound by reading
rules and counterexamples and not code? The gate is the four observations in the
analysis, section 6.

Phase 0 alone is a **need**, from facts in the code at `c387317`: nothing runs the tests
automatically, and the suite has not been run on the versions Stratta requires since
`timeline.ex` last changed
([the tests issue](../../issues/2026-11-27-timeline-tests.md), item 1).

Evidence so far, all from one module run by itself: generated tests found four
behaviours no existing test describes, and a run of seeded bugs showed that 36 in 100
pass every test ([the fold](../../issues/2026-11-27-timeline-fold.md),
[the tests](../../issues/2026-11-27-timeline-tests.md)).

Not met in use: any defect in a running daemon. Stratta has not been used for real work.

The order of the phases, and every "should" below, is the drafting agent's suggestion
([design commitments](../../docs/design-commitments.md), 4).

## What exists today

- 48 example tests across the three apps. No generated tests, no linter, no CI.
- `Stratta.Timeline` is a pure fold and `Stratta.API` is one command surface: the two
  shapes that generated tests need.
- The spike's scripts, kept beside the analysis in
  [`spike/`](../../analysis/2026-11-27-verification-design/spike/). They run on a cloud
  session's Elixir 1.14 with no Mix and no Hex.

## Decisions

All proposed. None is accepted until the operator says so.

- **D1. The operator reads rules, counterexamples and an evidence report.** A rule is one
  sentence with an id and a scenario. A counterexample is the shortest sequence that
  breaks a rule. The report lists, for a change, each rule, whether its check ran and
  fired, the seeded bugs that survived, and what was run and on what.
- **D2. Layers, cheapest first.** (0) a gate: compile with warnings as errors, format,
  tests, on every push; (1) generated tests for the pure modules; (2) the daemon tested
  as a state machine through `Stratta.API`, restarts included, with a scripted agent;
  (3) scenarios held back from the coding session; (4) checks on the checks; (5) a review
  agent, advisory; (6) the rules run over stored threads.
- **D3. Checks on the checks.** A fix ships with a test shown failing first. Anything
  that detects ships with a control that proves it can fail. A rule whose check never
  fired is reported. A seeded-bug run is read as a list of survivors to decide on; no
  score is a target.
- **D4. The builder does not grade itself.** What counts is the gate's result on a
  machine the coding session does not control. A change that weakens a check says so
  first. Where rules and held-back scenarios live waits on the operator
  ([where rules live](../../analysis/2026-11-27-where-rules-live/where-rules-live.md)).
- **D5. PropertyDamage at layer 2 if a spike says yes**, and StreamData with the spike's
  pattern if it says no
  ([PropertyDamage](../../analysis/2026-11-27-property-damage/property-damage.md)).
- **D6. Require Elixir 1.20, together with the gate**
  ([Elixir 1.20](../../analysis/2026-11-27-elixir-1-20/elixir-1-20.md)).

## Phases

### Phase 0: something that runs the tests (need)

On a machine with the required versions: the suite's first run, already a step in
`next.md`. Then a CI workflow that runs it on every push, and one Mix alias that runs
the gate. If D6 is accepted, the Elixir floor and `.tool-versions` go in here, after one
compile on 1.20 has been read.

### Phase 1: rules and generated tests for the timeline

The fourteen rules from the spike written down as the first rules file, with the
operator's answers on
[open tool calls](../../analysis/2026-11-27-open-tool-calls/open-tool-calls.md) and
[events the fold cannot read](../../analysis/2026-11-27-malformed-events/malformed-events.md).
`stream_data` as a test-only dependency, and the spike's properties moved into
`core/test`. Each open item in the fold issue fixed with its test shown failing first.
The seeded-bug run repeated, and each survivor either covered by a rule or recorded as
making no difference.

### Phase 2: PropertyDamage against the API (the spike in D5)

Six commands, the demo agent, five rules, on a machine with the required versions. It
answers the four questions in the PropertyDamage analysis, section 8, and settles
[the terminate issue](../../issues/2026-11-27-thread-server-terminate.md) on the way.

### Phase 3: held-back scenarios and an agent that misbehaves

A place for scenarios the coding session cannot read, if D4's question is answered that
way, and the scripted agent from
[adversarial-boundaries](../2026-11-26-adversarial-boundaries/adversarial-boundaries.md)
Phase 0. One fixture serves both plans.

### Phase 4: seeded bugs as a routine

A maintained tool (Muex or mutagen_ex were found; neither was tried) on the pure
modules, weekly. Its output is the survivors list in the report.

### Phase 5: the edges, each alone

A Quint model of the request protocol. Bombadil against the terminal client and the
app. The rules run over stored threads, which joins
[event-log](../2026-11-26-event-log/event-log.md) Phase 4.

## What it waits on

Each is an `(operator)` step in `next.md` with its analysis:

- what the design rests on: this assembly, or something else;
- what a thread shows for a tool call that never finished;
- whether folding an event may raise;
- where rules and held-back checks live;
- whether to require Elixir 1.20.

And one agent step: the PropertyDamage investigation.

## Not in scope

- A spec toolkit, a harness that runs agents, a proof assistant, or a score to reach.
- The front ends, until Phase 5.
- Security under an adversarial agent beyond the rules written for it; that is the
  adversarial-boundaries plan.
