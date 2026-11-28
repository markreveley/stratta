---
type: plan
kind: exploration
---

# Context assembled for each request: a step between running agents and owning the loop

> Status: proposed · 2026-11-27

## Summary

There are three ways Stratta can stand in relation to an agent's context.

1. **A session.** Stratta opens a conversation with an agent and relays messages into it.
   The agent decides what it remembers. This is today.
2. **A request.** Each message from the operator starts a fresh run of the agent, and
   Stratta writes everything that run begins with. The agent still runs its own loop,
   its own tools and its own permission requests inside the run.
3. **A loop.** Stratta calls a model itself, turn by turn, and owns every token. This is
   a harness of its own, and nothing in this repository proposes it yet.

This plan is the second, treated as an experiment and not as a feature. It moves the
point where Stratta controls context from once per thread to once per request, using the
agents Stratta already runs, and it looks at what that costs and what it buys. What to
do with what is found, including whether the third is worth building, is the operator's
to decide when there is something to look at.

## Why this exists

Kind: **exploration**.

No problem observed in use motivates this. It was asked for by the operator on
2026-11-26, as a promising direction to look into: a possible step between running
other people's agents and Stratta owning a loop of its own. It is early. The aim is to
find out what happens, not to rule on it.

The first agent is Claude Code, whose print mode (`claude -p`) runs one request and
exits. Codex has a non-interactive mode of the same kind. What each provides is Phase
0's question; nothing here was checked against their current documentation.

## The constraint it works inside

[Context as a recorded query](../2026-11-25-context-queries/context-queries.md) states it: Stratta does not own an
agent's context window. That stays true inside a run. A single request can be dozens of
tool calls, and what the agent keeps in view during them is the agent's business. What
changes is only how often Stratta gets to choose the starting material.

## What happens today

Checked in the code on 2026-11-26:

- `Stratta.ThreadServer` holds one session per thread and sends each message into it. A
  restarted thread resumes its previous conversation with the provider.
- The only place Stratta assembles starting material is a hand-off, when a thread
  continues under a different agent in the same folder.
- The timeline holds every event of the thread, in order, whatever the agent has since
  forgotten.
- Whether each agent can be run for exactly one request, with no memory of the last, and
  what that run reads by itself (instruction files, settings, memory) has not been
  looked at here.

## Design

### 1. A thread has a context mode

`session`, as today, or `request`. Set when a thread is made and shown wherever a
thread's agent and model are shown. A thread in `request` mode opens a session, sends one
assembled prompt, lets the run finish, and closes the session. Requests the agent raises
during the run are held and answered exactly as now.

### 2. An assembler, and it is pure

A function from the thread's timeline, its folder's state, the new message and a size
budget to the text the run starts with. No process, no clock, no model. Tested like
`Stratta.Timeline`.

What it can draw on, cheapest first:

- the operator's messages and the agent's final reply to each;
- what changed on disk: the diff against the base commit, as a summary of files;
- requests answered and how, from [decision records](../2026-11-25-decision-records/decision-records.md) when they
  exist;
- claims, from [the claim graph](../2026-11-25-claim-graph/claim-graph.md) when it exists.

The folder carries itself. Files the agent wrote are there for the next run to read, so
the assembler's job is what the folder cannot say: what was asked, what was decided, and
what is still open.

### 3. Every assembly is recorded

The same record the context-queries plan defines for a hand-off seed: which items went
in, by id, the budget, the size, and the rule that chose them. Nothing a model wrote goes
in unmarked. A run can then be explained afterwards by what it was given. The ids hold
across a restart of the daemon, since Phase 1 of [ids and a log of events](../2026-11-26-event-log/event-log.md).

### 4. What to look at

Some pieces of work done in both modes, from the same starting point, with the same
agent and model. Worth recording for each:

- whether the work got done, and how well;
- tokens in and out, and how much of the input came from the provider's cache, where
  the agent reports it;
- wall time;
- re-reading: tool calls that read a file an earlier request already read;
- anything noticed that the numbers do not show: what the fresh run forgot that
  mattered, what it was spared that would have misled it.

One cost is expected: a fresh run reads again what a session would remember, and a
rebuilt prompt gives up most of the cache. Whether choosing the starting material buys
that back is the interesting part.

How many tasks, how many repeats and what counts as a meaningful difference are left
open on purpose. Nobody has enough experience with this yet to set them, and a first
look at a handful of tasks will say more about what to measure than a rule written in
advance. The evals harness in artifact-dag's `evals/` is there when a more careful
comparison is wanted.

### 5. Where this could lead

Not rules, only the shapes the result might take, so that whoever reads the findings
knows what to look for:

- A session may simply be better. Then a good hand-off seed is probably where the effort
  belongs.
- Starting fresh may be better, with what is lost being lost between requests. That
  points at the assembler.
- Starting fresh may be better, with what is lost being lost inside a run, in what the
  agent keeps or drops during its own loop. That is the case that would make a loop of
  Stratta's own interesting.
- Or it may depend on the kind of work, which would be the most useful thing to learn.

[Graphs](../2026-11-26-graphs/graphs.md) has a table of what each of the three relations allows for claims
and decision records: what Stratta can put in front of an agent and when, and what can
be written back.

## Phases

### Phase 0: what each agent's one-request mode is (small; needs a machine with the agents installed)

For each agent Stratta runs: can a run be started with no memory of earlier runs; what
it reads by itself at start and whether that can be turned off; whether the start text
can be replaced or only added to; whether requests for permission arrive as they do in a
session; what it reports about tokens and cache use. And one question about the layer
underneath: does opening and closing a `Jido.Harness` session per request cost anything
beyond starting the agent's process. Findings, with fixtures.

### Phase 1: the mode and the assembler, against the demo agent (small to medium)

`context: request` on a thread, the assembler with its first two sources, the record of
each assembly, and `stratta context <thread>` to show the last one. Tests: the assembler
as a pure function; a demo-agent thread of three requests whose second and third runs
start from assembled text; a request raised mid-run answered as usual.

### Phase 2: one real agent, measured (medium; needs Phase 0)

Some real work done both ways with Claude Code, `session` against `request`, recording
what Design 4 lists. Written up with what was seen, whichever way it falls, for the
operator to read.

### Phase 3: claims as a source (small; needs step 14 of `next.md`)

The assembler drawing on claims, as a third arm of the same comparison. Shares its
record and its harness with the context-queries plan, and should be run with it.

### Phase 4: what was learned (small)

Which of Design 5's shapes the result took, with the evidence, and what the operator
decided. If a loop looks interesting, a list of what a
loop would have to do, which is the first page of a plan that does not exist yet.

## Not in scope

- A harness of Stratta's own. This plan decides whether to propose one.
- Summaries written by a model as starting material. If they are tried, they are a
  marked source in the record and a separate arm.
- Changing what an agent does inside a run.

## Open questions

- Does a thread switch modes part-way, or is the mode fixed at creation? Fixed is
  simpler to compare.
- Is one request one operator message, or can the operator hold a run open for a short
  exchange? The second blurs the comparison.
- Do pane threads have a `request` mode at all? An agent's own interface in a pane is a
  session by nature.

## Findings

None yet.
