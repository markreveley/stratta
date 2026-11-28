---
type: plan
kind: exploration
---

# Graphs: what a thread leaves behind, and work arranged across threads

> Status: proposed · 2026-11-27

## Summary

"Graph" is used for two different things in writing about agents, and Stratta's plans
already contain most of one of them.

1. **A graph of what was decided and on what grounds.** Decisions, the events behind
   them, claims, and the starting material built from claims. This is
   [decisions as records](../2026-11-25-decision-records/decision-records.md), [claims](../2026-11-25-claim-graph/claim-graph.md),
   [context as a recorded query](../2026-11-25-context-queries/context-queries.md) and
   [context for each request](../2026-11-26-per-request-context/per-request-context.md). This plan calls it the record
   graph. It adds nothing to those plans; it names what they share and says what each
   relation to an agent's context allows.
2. **A graph of work.** Threads as points, with a line from one to another when the
   first one's outcome is the reason the second was started. Stratta has the points and
   the places where work stops. It has no lines, no stated outcome for a thread, no check
   that does not go through a model, and nothing that runs such a graph. This plan is
   about that one, and calls it the work graph.

Nothing here is scheduled except a reading and one spike that rides on a build another
plan already needs.

## Why this exists

Kind: **exploration**.

Asked for by the operator on 2026-11-26, after reading a playbook on "graph engineering"
and asking whether Stratta should adopt it or could be the thing it is built on. No use
of Stratta has called for either graph. The outside evidence is mixed, and *What others
have found* gives it as it is. Phase 0 is reading and one spike, and may be where this
stops.

## Two graphs under one word

| | The record graph | The work graph |
| --- | --- | --- |
| Points | decisions, events, claims, seeds | threads |
| Lines | "is evidence for", "rests on", "was given to" | "this outcome led to that thread" |
| Written by | the daemon, from what it already holds | whatever starts the threads |
| Where it is planned | four plans, steps 9, 20 and 21 of `next.md` | here |
| What it is for | answering "why", and choosing what a thread starts with | doing work in more than one thread and knowing how it went |

The discussion that made the phrase common in July 2026 was about the second. The
playbook's "graph stage", a knowledge graph that agents share, is nearer the first.

## What a work graph needs, and what exists

Checked against the code at `3782faf`:

| It needs | Stratta has | Missing |
| --- | --- | --- |
| A point: one bounded run of an agent | A thread: a supervised process, its own session, optionally its own worktree | A stated outcome. A thread ends in prose |
| A place where control comes back | A permission request with a name (`2a`), the end of a turn, shipping | Nothing |
| A line | `handoff_from` on a thread made by a hand-off | A parent link ([surfaces drawn from behaviour](../2026-11-25-behaviour-shaped-ui/behaviour-shaped-ui.md) Phase 1, step 19) |
| A check that is not a model's opinion | The diff against the base commit | Running the project's tests in a thread's folder and reporting pass or fail |
| A record of the run | The timeline, per thread | Which threads belonged to one piece of work, and which outcome led where |
| Something to run it | Nothing; no model or script is in Stratta's own path | See Design 5 |
| A rule for who may answer | Reaching the socket | The grant ([authority for an answer](../2026-11-25-delegated-authority/delegated-authority.md), step 16) |

## What the record graph can do under each relation to context

[Context for each request](../2026-11-26-per-request-context/per-request-context.md) lists three ways Stratta can stand to
an agent's context. Each allows something different.

| Relation | When Stratta chooses what the agent starts from | What can be written back, and by whom |
| --- | --- | --- |
| A session (today) | Once, at the start of a thread or at a hand-off: the seed | The daemon, at each answered request |
| A request | Before every request | The daemon, at each answered request and after every run |
| A loop | Before every call to the model | The daemon as before. A model could also write, if that were allowed |

Two things hold in all three. An agent can be offered a tool that queries the record
graph during a run ([code mode](../2026-11-25-code-mode-orchestrator/code-mode-orchestrator.md) Phase 4 is where tools are
offered to agents); that is the agent choosing to look, not Stratta choosing what it
sees. And who may write is a separate decision from who owns the context. The rule in the
claims and decision-record plans, that nothing a model wrote goes in unmarked, does not
depend on the relation.

So the playbook's picture of every agent reading and writing one shared graph cannot be
built under a session, can be built at the edges of each run under a request, and can be
built in full under a loop. Whether it should be is a different question, and the one
[claims](../2026-11-25-claim-graph/claim-graph.md) Phase 0 and step 21 are there to inform.

## Design

Proposals, each small enough to be tried alone.

### 1. A thread is the point

Nothing changes about a thread. A point in a work graph is a thread, started and watched
through `Stratta.API` like any other.

### 2. An outcome

A few fields on the thread record, set by the daemon and by no model: whether the last
turn ended, failed or was interrupted; whether anything is waiting; whether the thread
was shipped; and the result of the last check (Design 3).

### 3. A check

`thread.check`: run the project's check command in the thread's folder and return its
exit status and the end of its output, as an item in the timeline. The command is set
per project in the data directory and is not an argument, for the reason rules live
there in [policy as actions](../2026-11-25-policy-as-actions/policy-as-actions.md): an operation that runs whatever a
caller sends is a different thing from one that runs what the operator configured.

### 4. A line, and a record of the run

The parent link from step 19, plus one field on the child saying what in the parent led
to it: a hand-off, an outcome, a check that failed. A piece of work across threads is
then readable from the thread records alone: which threads, in what arrangement, and why
each was started.

### 5. Something to run it

Three candidates. They differ in what the graph *is*.

| Candidate | The graph is | For it | Against it |
| --- | --- | --- | --- |
| A script, as in [code mode](../2026-11-25-code-mode-orchestrator/code-mode-orchestrator.md) | Code a model writes and a sandbox runs | Where Claude Code's dynamic workflows and Codex's code mode have gone; a loop and a wait are one line each | A sandbox and a second language runtime to keep safe; the graph cannot be looked at, compared or drawn before it runs |
| A `Jido.Flow` under `Jido.Durable` | Data: a named set of calls to actions, checked when built, storable as JSON | Can be shown before it runs; a wait holds no process; documented as needing no AgentServer, so `ThreadServer` would keep its session (Route A) | Jido is a beta; underneath is Runic, an alpha; an agent's conversation still ends with the virtual machine, so what a waiting flow resumes into has to be designed |
| A module written by hand | Elixir, calling `Stratta.API` | No dependency; the first graph can be written this way today | Waits, saving and looking inside it are all to be built |

Reactor, Runic used directly, and Journey were read as well. What was found is in
*Read, not run*.

### 6. Authority

Whatever runs a work graph is one more thing that can call `thread.approve`. It answers
nothing without a grant, under the same check that stops a script or a rule answering a
request from the thread it runs in.

## What others have found

Given here so that the reader can weigh it, not as a case for or against.

- The phrase spread after a post by Peter Steinberger in July 2026, and write-ups of it
  separate two meanings, a graph of facts and a graph of work
  ([teklens](https://teklens.ai/en/pm-lab/graph-engineering)).
- Anthropic's dynamic workflows in Claude Code have the model write a script that a
  runtime then runs across many sub-agents
  ([announcement](https://claude.com/resources/articles/introducing-dynamic-workflows-in-claude-code)).
  That is the code-mode plan's shape.
- LangChain's account of three years with LangGraph says that what is new is a point
  that is itself a whole agent, and also that its own deep-research product moved from a
  fixed graph back to a loop
  ([post](https://www.langchain.com/blog/3-years-of-graph-engineering-with-langgraph)).
- Jeremiah Lowin's "directed agentic graphs" define a point by an outcome that can be
  checked, and put verification, policy and people at the boundaries between points
  ([post](https://jlowin.dev/blog/directed-agentic-graphs)). Stratta's stopping points
  are such boundaries.
- A study of 180 arrangements by Google and others found that every arrangement of
  several agents did worse than one agent on tasks made of steps that depend on each
  other, and that several agents under one coordinator did better on tasks that split
  into independent parts ([paper](https://arxiv.org/abs/2512.08296)). Its tasks were not
  coding tasks.
- ContextRender, a preprint of September 2026, chose which earlier tool results to show
  a model by recency, relevance and whether they were reused later, and did better than
  five other ways of fitting a history into the same size
  ([paper](https://arxiv.org/pdf/2609.37743)). It bears on step 21, and it is a result
  about one agent's history, not about hand-offs.

## Read, not run

### Jido, at `14424fe` (`3.0.0-beta.3`)

More of this exists than [policy as actions](../2026-11-25-policy-as-actions/policy-as-actions.md) uses.

- **Flows** (`guides/flows/`, `lib/jido/flow.ex`): a named graph of calls to actions.
  Its parts are `step`, `choice`, `map`, `reduce`, `parallel`, `iterate` (a loop with a
  bound), `invoke` (pick the target while running), `handoff`, and three that wait:
  `await`, `timer` and `selection`. A flow can be written in a module, built from maps,
  or stored as JSON. It is compiled to a Runic graph.
- **Waits** (`guides/flow-runtime/flow-waits.md`): a waiting flow saves its position and
  holds no process. The guide's example waits for a reviewer to approve or reject, with
  a time limit. A wait needs a host that saves: an AgentServer with persistence, or
  `Jido.Durable`.
- **Durable runs** (`lib/jido/durable.ex`): described as independent of agents and
  AgentServer. They use a named Jido instance and its persistence adapter, save at the
  boundary of each part, and own no scheduler.
- **Stores** (`guides/storage/`): among them a file adapter for one virtual machine with
  a local disk.
- **Topology** (`guides/composition/`): an agent can declare member agents and
  connections that route one member's output to another.
- **A blackboard** (`lib/jido/blackboard.ex`): a named board that is read as a snapshot
  with a revision and changed by a patch that fails if the revision has moved.
- **Also**: statecharts in SCXML, behaviour trees, an append-only thread value, a trace
  value in the W3C form, expressions that are data and never code (`lib/jido/expr.ex`),
  and a catalog that resolves an id and version to a registered value.

### Reactor, Runic and Journey

| | Read at | What it is | For a work graph in Stratta |
| --- | --- | --- | --- |
| Reactor | `7b4134c`, 1.0.8, MIT | Steps whose arguments give their order, run together where they can, each with an undo | Stable. A halted run comes back as a value; keeping it across a restart is the caller's to build. Its strength is undoing a half-done procedure, which is a different job |
| Runic | `0c15a9c`, 0.1.0-alpha.13, Apache-2.0 | Workflows as data put together while running, with a runner and a store behaviour (memory and Mnesia built in) | What `Jido.Flow` compiles to. Taken directly it is smaller than Jido and still an alpha |
| Journey | `fe8e90d`, 0.11.1, Apache-2.0 | A graph of values where setting one runs what depends on it, each value saved as it is set | Its state lives in PostgreSQL. Stratta keeps files in `~/.stratta` and runs as a guest in a terminal |

## Phases

### Phase 0: reading, and one spike (small; the spike rides on policy Phase 0)

The reading is done and is above. The spike uses the build that
[policy as actions](../2026-11-25-policy-as-actions/policy-as-actions.md) Phase 0 makes, `core/` with `jido` added:

- one flow whose steps are actions that call `Stratta.API` (make a thread with the demo
  agent, send it a message, wait until it is idle), with a wait for an approval;
- run under `Jido.Durable` with the file adapter and no AgentServer;
- recorded: whether it compiles and runs that way; what a waiting flow is on disk; and
  what the flow sees when the daemon restarts while the thread it started is mid-turn.

Findings, written below.

### Phase 1: an outcome and a check (small)

Design 2 and 3: the fields, `thread.check`, `stratta check <thread>`. Tests with the demo
agent: a check that passes, one that fails, and a project with no check command set.

### Phase 2: the first graph, by hand (medium; needs Phase 1 and step 19)

The task the code-mode plan names as its own first proof, with no model and no sandbox:
run one prompt on two agents in separate worktrees, wait for both, run the check in
each, and report which passed. Written as an ordinary module against `Stratta.API`, with
Design 4's record kept. Against the demo agent first, then a real one.

The same prompt in one thread is worth doing beside it. What to compare and how often is
left open, as in [context for each request](../2026-11-26-per-request-context/per-request-context.md).

### Phase 3: how graphs are run (writing, then the operator's decision)

With Phases 0 and 2 done, set down what each of Design 5's candidates would take and
give. Which to build, if any, is the operator's.

## Not in scope

- A graph of facts drawn out of transcripts by a model. [Claims](../2026-11-25-claim-graph/claim-graph.md) rules
  the same thing out.
- A fixed cast of agents with roles.
- A model that runs graphs. That is [code mode](../2026-11-25-code-mode-orchestrator/code-mode-orchestrator.md) Phase 3.
- An agent that answers requests. That is [an agent as an approver](../2026-11-25-agent-approver/agent-approver.md),
  which the operator has left unscheduled.

## Open questions

- Is a thread's outcome set at the end of every turn, or only when asked for?
- Does a check belong to a project, to a thread, or to a point in a graph?
- When a waiting flow resumes after a restart and its thread's conversation is gone, is
  the honest outcome "interrupted", for the graph to decide what follows?
- If a graph is data, who may write one: the operator only, or a model, with the graph
  shown before it runs?

## Findings

- 2026-11-26, Phase 0 reading: as under *What others have found* and *Read, not run*.
  Jido, Reactor, Runic and Journey were read from clones at the commits named and none
  was compiled or run. The spike has not been done.
