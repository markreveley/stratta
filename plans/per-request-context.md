---
type: plan
kind: exploration
status: proposed
created: 2026-11-26
---

# Context assembled for each request: a step between running agents and owning the loop

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
agents Stratta already runs, and it measures what that costs and what it buys. Its last
phase is a written answer to one question: is the third worth building, and for what?

## Why this exists

Kind: **exploration**.

No problem observed in use motivates this. It was asked for by the operator on
2026-11-26, toward the question of whether Stratta should ever own a loop. It should be
judged as an experiment: cheap, gated, and allowed to end in "no".

The first agent is Claude Code, whose print mode (`claude -p`) runs one request and
exits. Codex has a non-interactive mode of the same kind. What each provides is Phase
0's question; nothing here was checked against their current documentation.

## The constraint it works inside

[Context as a recorded query](context-queries.md) states it: Stratta does not own an
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
- requests answered and how, from [decision records](decision-records.md) when they
  exist;
- claims, from [the claim graph](claim-graph.md) when it exists.

The folder carries itself. Files the agent wrote are there for the next run to read, so
the assembler's job is what the folder cannot say: what was asked, what was decided, and
what is still open.

### 3. Every assembly is recorded

The same record the context-queries plan defines for a hand-off seed: which items went
in, by id, the budget, the size, and the rule that chose them. Nothing a model wrote goes
in unmarked. A run can then be explained afterwards by what it was given.

### 4. What is measured

A fixed set of tasks, at least ten, each with a check that passes or fails by itself: a
test suite that goes green, a file that matches. They run through the evals harness in
artifact-dag's `evals/`. Each task is run three times in each mode, from the same commit,
with the same agent and model.

- **Done.** How many of the tasks pass. This is the primary measure.
- **Cost.** Tokens in and out per task, priced with the provider's cache discount where
  the agent reports cache use.
- **Time.** Wall time per task.
- **Re-reading.** Tool calls that read a file an earlier request in the same thread
  already read. Explains cost; decides nothing.

The spread between the three runs of one mode is the noise. A difference between modes
smaller than that spread is no difference.

The expected loss is known in advance: a fresh run reads again what a session would
remember, and a rebuilt prompt gives up most of the cache. The experiment is whether
choosing the starting material buys back more than that.

### 5. What counts as losing, written before anything runs

- **`request` loses** if it passes fewer tasks than `session` by more than the noise; or
  if it passes the same number, within the noise, at more than one and a half times the
  cost or the time. Then stop. Sessions with a good hand-off seed are enough, and a loop
  of Stratta's own is not indicated.
- **`request` wins** if it passes more tasks by more than the noise, or the same number
  at no more than the same cost. If what is still lost is lost between requests, improve
  the assembler. Still no loop.
- **A case for the loop** exists only if `request` wins and the tasks it still fails are
  failed inside a run: the agent dropped or kept the wrong thing during its own loop.
  The write-up names those tasks and what a loop would have to do about each.

Anything between losing and winning is "no result at this size", and the answer is more
tasks, not a conclusion. The one and a half is a starting figure and may be changed in
Phase 2, in writing, before the first measured run and not after.

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

The measures of Design 4 for Claude Code on the task set, `session` against `request`.
Written up with the numbers, whichever way they fall. This is the first gate: if
`request` loses by Design 5's definition, the plan ends here.

### Phase 3: claims as a source (small; needs step 14 of `next.md`)

The assembler drawing on claims, as a third arm of the same comparison. Shares its
record and its harness with the context-queries plan, and should be run with it.

### Phase 4: the answer (small)

Which of Design 5's outcomes held, with the evidence. If the third, a list of what a
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
