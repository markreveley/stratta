---
type: plan
status: proposed
created: 2026-11-25
---

# Where a thread's files and processes live

## Summary

A thread today runs on the operator's machine: the agent is a child process, the files are
a git worktree under `.stratta/worktrees/`, and committing and pushing happen on the host
with whatever credentials are already there. This plan names that arrangement as one
implementation of a behaviour, so that a thread can also run somewhere else — a machine the
operator keeps, with instant filesystem clones and checkpointable virtual machines — without
the rest of Stratta knowing which.

The first such place is **Mjolnir**, a compute fabric that starts checkpointable Linux
microVMs from copy-on-write clones. It is named here under the exception in
[design commitments](../docs/design-commitments.md): providers of environments may be
named. Two uses are in view and only the first is this plan's: Mjolnir as where a
thread's files and processes live, behind the behaviour; and the daemon itself running
inside a Mjolnir machine so that it is always on, which needs nothing from this plan
beyond a Linux machine with Elixir and has not been tried.

The word **environment** is used throughout and "sandbox" is avoided, because this
repository already uses that word twice for other things: `sandbox_mode` on a Harness
session, and the script sandbox in [code mode](code-mode-orchestrator.md).

This is an independent track. Nothing in the other plans needs it, and it needs none of
them.

## What it would unlock

- **Branching the whole thread.** The README lists `fork_session_id` for "branch this
  conversation". With a checkpointable environment it is branch the conversation *and* the
  working tree, the dirty files, the running dev server and the test database — the state a
  worktree cannot carry.
- **A thread that starts warm.** An environment created from a prepared checkpoint has the
  dependencies fetched and compiled already. The first turn stops paying for setup.
- **Tests that mean something.** A database and the services beside the thread, provided by
  the environment rather than provisioned by the agent.
- **A terminal that survives.** A pane that lives in the environment outlasts the window it
  was opened in, which is what [pane threads](pane-threads-via-hooks.md) wants and cannot
  have locally.
- **Blast radius.** An agent running commands on a machine that is not the operator's.

## The spike that decides whether any of this is viable

Stratta stores no credentials and uses each agent CLI's own login. **A fresh environment
has no login.** Before anything is designed, find out per agent: what the login consists
of on disk, whether it can be placed in an environment without being copied through
Stratta, whether it survives a checkpoint and restore, and whether it survives being
restored *twice* — because two forks of one checkpoint are two processes holding one
credential.

If the honest answer is that a login cannot get into an environment without Stratta
handling it, that collides with the project's own rule about credentials, and this plan
stops at the behaviour and the local implementation. That would still be worth having.

## Design

`Stratta.Environment`, a behaviour with the operations the rest of Stratta actually needs
and nothing more:

- create, optionally from a named checkpoint; destroy;
- run the agent process inside it, with its working folder;
- attach a terminal to it;
- read the diff out against the base commit, and read a file out;
- checkpoint it, and create from that checkpoint;
- report what it provides (services, addresses) so a thread can be told.

`Stratta.Environment.Local` is today's behaviour, unchanged, and the refactor is done when
every existing test passes against it with nothing else altered. Other implementations are
configured in the way a provider is, and **live outside this repository.**

### The parts that are genuinely hard

- **Shipping moves inside.** Commit, push and opening a pull request currently run on the
  host. In a remote environment they run where the files are, which means a push
  credential has to be reachable from there. The right shape is not a secret in the
  environment but a narrow operation it may ask for — "push this branch" — brokered by
  something that holds the credential and never hands it over. That broker is not Stratta;
  Stratta calls it. This reuses the grant idea from
  [delegated authority](delegated-authority.md) and is the first place it earns its keep
  outside the approval path.
- **Admission after a restore.** A restored checkpoint comes back holding live credentials
  and a live session. Two restores of one checkpoint are two claimants to the same
  identity. A restored environment has to re-establish that it is allowed to resume, with
  something that distinguishes one restore from the next; otherwise forking replays
  authority. This is a protocol question, the operator has an implementation of exactly
  this shape elsewhere, and Stratta's part is only to carry the answer.
- **The diff boundary.** Reading changes out of a remote environment, at the size real
  repositories reach, without copying the tree.

## Phases

### Phase 0: the login spike (small, and it gates everything)

As above. Write the answer per agent into Findings. Do not design before it is answered.

### Phase 1: the behaviour and the local implementation (medium, no new behaviour)

Extract `Stratta.Environment`, implement it with today's code, change nothing the operator
can see. Done when the suite passes unaltered.

### Phase 2: an external implementation, read-only (medium)

A thread that runs in an external environment and can be watched: create, run the agent,
stream the timeline, read the diff out. No ship, no checkpoint, no pane.

### Phase 3: shipping from inside (medium)

The brokered push, per the shape above. Needs the authority plan's narrowing.

### Phase 4: checkpoints and forking (medium to large)

Create from a checkpoint, checkpoint a running thread, and fork a thread with its files —
including whatever the admission question above requires.

### Phase 5: a pane in an environment (medium; after pane threads)

A terminal in the environment, surviving the window. By this point the app-first plan's
Phase 4 has already put a shell behind `shell.open`, `shell.input` and a subscription, so
this is a second implementation of those operations rather than a new surface — which is
the test of whether the environment behaviour was drawn in the right place.

## Not in scope

- Any implementation other than local, in this repository.
- Scheduling across several machines.
- Running the daemon itself remotely. That is [remote access](remote-access.md).

## Open questions

- ~~Does the daemon stay on the operator's machine and drive a remote environment, or does
  a daemon run in each environment?~~ Settled on 2026-11-25 by Design 8 of
  [the app first](gui-first.md): a remote host means a daemon on that machine, reached
  through its own socket, because everything that touches a thread's folder is the daemon's
  work. An environment follows the same rule, which also means the shell, the files and the
  diff need no second remote form.
- Where does the base commit live when the repository is cloned into an environment, and is
  the thread's branch pushed from there or from the host?
- Is an environment per thread, or per project with threads sharing it? Per thread is the
  honest answer for isolation and the expensive one.

## Findings

*To be filled in by Phase 0, and that phase gates the plan.*
