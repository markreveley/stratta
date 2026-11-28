---
type: plan
kind: exploration
---

# Code mode: let a model drive Stratta by writing code

> Status: proposed · 2026-11-27

## Summary

Today no model calls tools inside Stratta. The daemon starts agents in their protocol
mode, each agent runs its own model loop and handles its own tools, and Stratta's own
path (thread, timeline, socket, views) has no model in it.

That changes once Stratta becomes a harness: a model that manages threads rather than one
that works in one. It would start several agents on a task, wait for them, compare their
diffs, answer the requests a rule can settle, and ship the best result. That work is
many calls in a row, each feeding the next, over results that are large (diffs,
timelines, test output).

This plan gives that model Stratta's operations as a **small typed library it writes code
against**, run in a sandbox, instead of one tool per operation. The model gets two tools:
**search** (find operations and read their signatures) and **execute** (run a script).
Loops, waits, filtering and joins happen in the script, and the model sees only what the
script prints.

It depends on there being an orchestrating model at all, so it comes after the current
steps in `next.md`. Phase 0 is cheap and worth doing earlier.

## Why this exists

Kind: **exploration**, except Phase 0.

It depends on an orchestrating model that does not exist and that nothing in use has
called for. The pattern is the one Cloudflare published as Code Mode and Anthropic
described for code execution with MCP: give a model a typed library and a sandbox
instead of one tool per operation.

Phase 0 stands by itself. A spec for every operation is documentation, it catches an
operation added without one, and it is most of the socket protocol document in
[views as separate programs](../2026-11-26-composed-surfaces/composed-surfaces.md).

## Why code rather than one tool per operation

| | One tool per operation | Search and execute |
| --- | --- | --- |
| What the model is given up front | Every operation's schema, every turn | Two short tool descriptions |
| A loop over five threads | Five or more calls, each a model round trip | One script |
| A 3,000-line diff | Goes into the model's context | Read in the script; the model sees "12 files, tests pass" |
| Waiting for threads to finish | Polling through the model | `await` in the script, on the socket's subscriptions |
| Growth | Context cost grows with every new operation | Constant |
| Cost | Nothing new to run | A sandbox to build and keep safe (see Safety) |

## What Stratta already has

Checked in the code on 2026-11-25:

- **`Stratta.API`** is already a closed set of named operations with JSON arguments and
  results, and it never raises: `ping`, `projects.list`, `projects.add`, `providers.list`,
  `threads.list`, `threads.create`, `thread.get`, `thread.slot`, `thread.send`,
  `thread.interrupt`, `thread.set_model`, `thread.approve`, `thread.diff`,
  `thread.commit`, `thread.push`, `thread.draft_pr`, `thread.ship`, `thread.handoff`,
  `thread.delete`, `current.get`, `current.set`.
- **`Stratta.Socket`** already pushes events: `subscribe` to one thread, to all threads,
  or to a workspace's current thread. That is what lets a script wait instead of poll.
- **Named requests** (`2a`) give a script a stable way to refer to a permission request.

What is missing: a description of each operation (arguments, result shape, one line of
what it does) that a library can be generated from, and somewhere safe to run a script.

## Design

- **The library is generated from `Stratta.API`, never written by hand.** Each operation
  declares its arguments, result and a one-line description next to its `run/2` clause
  (a module attribute or a small spec table). A mix task writes the typed library from
  that. The same table serves search. One source, so the library cannot drift from the
  daemon.
- **Search returns signatures, not everything.** `search("diff")` returns the matching
  operations with their types and descriptions. Listing everything is allowed but never
  done by default, so adding operations never costs the model anything.
- **Execute runs one script in a fresh sandboxed process** with a time limit, a memory
  limit and no network. Its only way out is a `stratta` object whose methods are the
  generated library. Whatever the script prints (or returns) is the tool result, cut to a
  fixed size with a note when cut.
- **The bridge is the control socket, narrowed.** The sandbox process does not open the
  socket itself. The daemon starts it with a pipe, and each library call is a framed
  request on the pipe that the daemon checks against an allow list before calling
  `Stratta.API.call/2`. That plays the part a capability binding plays: the script holds
  no handle the daemon did not give it.
- **Which operations a script may call is per orchestrator, not global.** A read-only
  orchestrator gets the `*.list`, `*.get` and `thread.diff` operations; one that may act
  also gets `send`, `approve`, `commit` and so on. `thread.ship`, `thread.push` and
  `thread.delete` stay off unless turned on.
- **The runtime is an open question.** It must start fast, run untrusted code with no
  file or network access by default, and have a type system the model writes well.
  A JavaScript or TypeScript runtime with a permission model is the obvious fit; Phase 0
  decides. Harness' native process helper can supervise the process either way.
- **Why the script does not run inside the daemon.** The reason is the virtual machine
  and not the language. Code loaded into a BEAM node can reach everything the node can:
  files, ports, other processes, the node's own modules. Its processes are kept apart so
  that a failure in one does not spread, not so that one cannot act on another. Dune, a
  sandbox for Elixir code, says of itself that code which escapes it has the whole
  virtual machine. So untrusted code runs either in a separate operating-system process,
  which is this design, or in an interpreter that happens to run on the BEAM, such as
  the `lua` package, or a WebAssembly runtime. The second reason is the language: models
  have written far more JavaScript, TypeScript and Python than Elixir. Read, not tried.
- **Agent-neutral.** The orchestrator is any model reached through `Jido.Harness` or a
  Jido Agent. Stratta exposes search and execute as tools; it does not care which model
  calls them.
- **The same tools can be offered to agents later.** A headless thread's session can be
  given extra tool servers. Stratta could offer search and execute over its own library
  to the agents it runs, so an agent can, for example, hand work to a second thread. That
  is Phase 4 and optional.

## The same work as a graph that is data

There is a second way to hand an orchestrating model the means to arrange work, and it
needs no sandbox: the model writes a description of the graph and not a program. In Jido
`3.0.0-beta.3` a flow can be stored as JSON, refers to actions by id and version through
a catalog, and uses expressions that are data and are never evaluated as code. A model
could then only arrange operations that already exist, and what it wrote could be shown
before it ran. Jido's guide is plain that a catalog is an inventory and authorises
nothing, so which operations a given writer may use stays the allow list's job, as in
Design above. And a description cannot do what a script can: an arbitrary loop, or
reading a large diff and printing one line about it.

[Graphs](../2026-11-26-graphs/graphs.md) sets the two beside a third, a module written by hand, and its
Phase 2 does this plan's first task (Phase 3 below) by hand before any model is
involved.

## How it fits with the other plans

- **Approval policy** (pane threads, Phase 3; the README's Jido Agent item): rules settle
  the requests they cover in code, and only the rest reach a person or the orchestrator.
  The orchestrator's scripts use the same `thread.approve`, so policy and orchestration
  share one path.
- **The agent must not approve its own requests** (pane threads, Safety). Scripts are
  started by the daemon, so it knows their process and which orchestrator they belong
  to. The same check applies: a script may not approve a request raised by a thread it
  is running inside.

## Phases

### Phase 0: describe the operations (small; useful on its own)

- Add a spec for every operation in `Stratta.API`: arguments, result shape, one-line
  description, and whether it only reads.
- `stratta ops` (and an `ops.list` operation) prints them. That doubles as reference
  documentation for the terminal client.
- A test that fails when an operation has no spec.

Done when every operation is described and the test passes.

### Phase 1: the sandbox (medium)

- Pick the runtime (see the open question). Measure start time and memory per script.
- `Stratta.CodeRunner`: start a sandboxed process with a script, the generated library
  and a pipe; enforce the time and memory limits; collect output; kill on timeout.
- The pipe protocol and the allow list check in the daemon.
- The mix task that generates the library from the Phase 0 specs.
- Tests: a script that lists threads; a script that tries the network, the file system
  and an operation not on its allow list, and is refused each time; a script that loops
  forever and is killed.

### Phase 2: search and execute as tools (small to medium)

- Two operations, `code.search` and `code.execute`, so any client of the socket can use
  them, then expose them as tools to a model session.
- Output trimming and a clear error result for a failed script (the model reads the
  error and tries again).
- Subscriptions inside scripts: `await stratta.waitForIdle(thread)` built on the socket's
  `subscribe`.

### Phase 3: an orchestrator thread (medium)

- A new kind of thread whose model has search and execute and no working folder of its
  own. Shown in the dashboard and the app like any other thread, with each script and
  its output as timeline items.
- First task to prove it: "run this prompt on two agents in separate worktrees, wait,
  and tell me which diff passes the tests". Done when that works end to end against the
  demo agent, then against a real one.

### Phase 4: offer the tools to agents (optional)

- Give headless threads the same search and execute tools, with a read-only allow list
  by default.

## Safety

- **Scripts are untrusted.** Model-written code runs with no network, no file access, a
  time limit and a memory limit, in a process the daemon started and can kill.
- **The library is the only way out**, and every call is checked against the
  orchestrator's allow list in the daemon, not in the sandbox.
- **Irreversible operations are off by default**: `thread.push`, `thread.ship`,
  `thread.delete`, and `thread.approve` for shell commands. Turning one on is a setting a
  person changes.
- **Every script and its output are kept** in the orchestrator's timeline, so what was
  done can be read back.
- **Nothing new on the network.** The sandbox talks to the daemon over a pipe; the
  daemon's socket stays private to its owner.

## Not in scope

- Running code from the agents' own conversations; agents keep their own tool handling.
- Hiding data from the orchestrating model beyond trimming output (for example, masking
  personal data in results).
- Remote access.

## Findings

*To be filled in by Phase 1 (runtime choice, start time, memory).*
