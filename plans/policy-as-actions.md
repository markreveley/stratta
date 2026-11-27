---
type: plan
kind: exploration
status: proposed
created: 2026-11-25
---

# Policy as actions: the Jido Agent integration

## Summary

The README's first next step is wrapping each thread in a Jido V3 Agent so that approval
policy can be written as Jido actions.
[Pane threads](pane-threads-via-hooks.md) Phase 3 says the same thing from the other side.
This plan is that work, and it supersedes that phase.

It is deliberately narrow. A Jido agent is introduced for **one** job — answering
permission requests — and `ThreadServer` keeps everything else. The point is to find out
what the discipline is like to work with before anything depends on it. The example it
uses is ordinary: answering file reads by rule.

## Why this exists

Kind: **exploration**, with a gate.

This was the README's first next step, written before Stratta had been used. The feature
it names, to stop asking the operator about file reads, is not confirmed as a need: the
operator's report on 2026-11-26 is that requests from coding agents have been
appropriate and informative. Waiting times from [decision records](decision-records.md)
will show whether any class of request is worth answering by rule.

What is left is an exploration of whether Jido's discipline pays, which is a fair reason
to do it.

## What Jido gives, in the terms this plan uses

- An agent is an immutable struct with one operation: actions in, new agent plus
  **directives** out. Directives describe effects (emit, spawn, schedule, stop); a runtime
  performs them. So a decision can be inspected before it happens.
- **Signals** are the one message envelope, a CloudEvents envelope. `Jido.Harness.Plugin.Command` already builds
  prompt, interrupt and approval-response Signals, so the shape Stratta would send is
  defined upstream.
- **Skills** are behaviour modules with their own slice of state and a schema that merges
  into the agent's. This is what makes a rule set something you add rather than something
  you patch in, and what lets a screen render state it has not seen before.

## What else Jido has

Read on 2026-11-26 in the Jido repository at `14424fe` (`3.0.0-beta.3`), not from a
build. Beyond agents, signals and plugins, that version has flows (graphs of calls to
actions, declared as data, with waits that hold no process), durable runs of flows that
are described as needing no AgentServer, agent topology, a blackboard, statecharts and
behaviour trees. None of it is needed for rules. It bears on Route B below, and
[graphs](graphs.md) lists it with the files it was read from.

## The decision this plan exists to make

`Jido.Harness.Plugin` is written to **own the session**: its `child_spec` starts a runtime
that holds the `Jido.Harness.Session` for one agent activation. `Stratta.ThreadServer`
owns that session today. The two cannot both own it, so there are two routes and they are
not variations on each other:

- **Route A — policy only.** Depend on `jido`, use plain Jido agents and skills for the
  rule set, keep `ThreadServer` owning the session. A rule set is a pure function from a
  request plus thread state to an answer; the agent holds the rules and their state and
  nothing else. Small, reversible, and it tests the discipline honestly.
- **Route B — the plugin owns the thread.** Adopt `Jido.Harness.Plugin`, and `ThreadServer`
  becomes a client of a Jido agent rather than the holder of a session. Everything in the
  rest of these plans gets easier — parent and child threads, scheduled wake-ups, state
  machines — and the timeline, the store, slots and the socket API all have to be re-fitted
  around a runtime Stratta does not control. Some of that list may not need Route B: a
  flow run under `Jido.Durable` can wait and resume, and is documented as independent of
  AgentServer. That is unverified, and Phase 0 is where it gets looked at.

Route A first is the suggestion here, with Route B looked at once A has run. `jido` is not a
dependency of this repository today; `Jido.Harness.Plugin` only compiles when it is
present. Phase 0 is the go/no-go on taking that dependency at all.

## Design (Route A)

- `Stratta.Policy`: a rule set per project, with a per-thread override, kept in
  `~/.stratta`.
- A rule is an action with a validated argument schema: match on tool, path, command
  shape, or the agent's own category for the request; answer allow, deny, or ask.
- Three rules ship, because they are the ones everybody writes first: allow reads inside
  the working folder, ask for shell commands, deny writes outside the working folder.
- Every automatic answer writes a [decision record](decision-records.md) naming the rule
  that fired. An automatic decision with no named rule is a bug.
- "Always allow this" in the app and the client appends a rule, and says which rule it
  appended. Where the agent's protocol accepts `updatedPermissions`, it is also passed
  back so the agent stops asking.
- Rules are evaluated in order, first match wins, and the order is shown.

## Safety

- **Default is ask.** A missing, unparseable or erroring rule set answers nothing; it never
  answers allow. Same rule as a failing hook.
- **Deny beats allow** when a later rule would widen an earlier denial, so that a rule
  added in haste cannot quietly open a hole.
- **No rule may answer a request from an agent-descended process.** The caller check in
  the pane-threads plan applies here too, and automatic answers must not become a way
  around it.
- Rules live in the data directory, not in the repository being worked on. A rule set that
  an agent can edit is a rule set an agent can widen.

## Phases

### Phase 0: go/no-go on the dependency (small)

Build `core/` with `jido` added and nothing else changed. Record: does it compile, what
comes with it, what does `Jido.Harness.Plugin` start when it is present, and does its
presence change existing behaviour? If the answer is bad, this plan continues with a plain
matcher and no Jido, and the rest of the plans are unaffected except that skills stop being
free. Write the answer into Findings.

With the same build, the spike in Phase 0 of [graphs](graphs.md): one flow whose actions
call `Stratta.API`, run under `Jido.Durable` with the file adapter and no AgentServer.
It is a separate question from the dependency and its answer goes into that plan.

### Phase 1: rules, without Jido in the way (small to medium)

The rule set, the three shipped rules, order and first-match, decision records naming the
rule, `stratta policy` to show the effective rules for a thread. Tests: a read allowed, a
shell command asked, a write outside the folder denied, an unparseable rule set asking for
everything.

### Phase 2: rules as Jido actions and a skill (medium; only if Phase 0 says yes)

The same rule set expressed as actions with validated schemas inside a Jido agent beside
`ThreadServer`, with the rules' state as a skill's state. Done when the Phase 1 tests pass
unchanged against the new implementation.

### Phase 3: "always allow this" (small)

From the app, the viewer and `stratta approve --always`, with `updatedPermissions` where
the agent accepts it.

### Phase 4: the Route B assessment (small, writing only)

With Phases 1 to 3 run, write into this plan what Route B would cost and what it would
unlock, for the operator to read.

## Not in scope

- An agent answering requests: [an agent as an approver](agent-approver.md).
- Authority for who may set a rule: [delegated authority](delegated-authority.md).
- Budgets, escalation and scheduled wake-ups. All of them are natural once rules are
  actions; none of them is needed to find out whether rules are worth having.

## Open questions

- Is a rule's match expressed over the agent's own permission categories, which differ per
  provider, or over a normalised shape Stratta derives? The first is honest, the second is
  portable.
- Does a per-thread override belong in the thread record or in the rule set?

## Findings

*To be filled in by Phase 0.*
