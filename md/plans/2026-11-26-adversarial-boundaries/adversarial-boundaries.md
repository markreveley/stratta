---
type: plan
kind: experiment
---

# Boundaries under an adversarial agent: what holds when the agent does not cooperate

> Status: proposed · 2026-11-27

## Summary

Stratta's controls today assume an agent that cooperates: it asks before it acts, it
describes what it is about to do accurately, and it leaves the socket, the record and
its own instructions alone. This plan finds out which of Stratta's boundaries hold when
an agent does none of that, and then builds the smallest version of a few that do not.
It starts from the operator's working assumption that agents are adversarial.

It measures before it builds. Phase 0 adds a scripted agent that misbehaves on purpose
and a set of tests that say, for each of Stratta's planes and each concern, whether a
boundary holds today. Most will not, and the tests say so by asserting the hole. The
later phases each take one selected aspect, build the smallest version, and report which
tests changed. One phase is a spike on the smallest second zone an agent can be moved
into on one machine, because the analysis concludes that most boundaries cannot hold
without one.

It builds no sandbox. The aspects it tests were selected from Replit's Agent Habitat
architecture, which [Habitat and Stratta](../../analysis/2026-11-26-habitat-and-stratta/habitat-and-stratta.md) reads against
this repository. That is a reference and not a dependency: nothing here takes anything
of Replit's, conforms to it, or scores Stratta against its scale.

## Why this exists

Kind: **experiment**, on a working assumption.

The assumption is the operator's, from a thread on 2026-11-26, lightly corrected for
typing:

> We need to assume adversarial agents. Maybe not technically for most work on my
> computer, but my theory is that we need to draw the connection between the user/agent
> UI substrate/system and a habitat-like model. To do this, all concerns need to be
> accounted for in all planes. I still don't know if this is wrong or contrived, but I'm
> starting with this assumption.

The question this plan is built to answer either way: does accounting for every concern
in every plane of Stratta produce anything the existing plans did not already have, and
does a habitat-like model have something to say about the surface where a person and an
agent meet? "No, it reduces to running the agent somewhere else" is a possible answer,
and so is "it was contrived".

What is fact, read from the code at `419ebb9` and not run: every agent runs as the
operator; the socket and the app answer any caller; a request is drawn from the agent's
own wording; the record is a set of files the agent can rewrite; the daemon runs the
repository's git hooks when it commits and pushes.

What is judgment: that an adversarial agent is the right thing to design for on one
operator's machine, and that the selection below is the right one. Both are the
operator's to change.

Not observed in use: any of it. No agent has been seen to do any of the things the
tests reproduce.

The named piece, read on 2026-11-26 through summaries and not in full: *Agent Habitat
Architecture*, Luis Héctor Chávez and Manish Mehta, Replit. Stratta's code names
nothing of it.

## What exists today

Checked in the code on 2026-11-26, at `419ebb9`:

- **The demo agent** (`core/priv/demo_agent/demo_acp.py`) is a scripted program. It
  lists files, asks permission before an edit, and writes one real file. It does not run
  shell commands and never misbehaves.
- **A request** is kept by `Stratta.Timeline` as a `title`, a `tool_kind`, `options` and
  `diffs`, all as the agent sent them. The raw input is kept for a tool call and not for
  a request. The app and the viewer show the title in bold beside the control.
- **Answering** is `thread.approve` on the socket, or the `approval` event in the app.
  Neither asks who is calling. `thread.send` and `thread.ship` are the same.
- **Cleaning of agent text.** The app HTML-escapes it and links only `http` and `https`.
  `Stratta.TUI.Status.clean/2` removes C0 and C1 control characters and bidirectional
  overrides. `Stratta.TUI.Render.fit/2` replaces C0 controls only.
- **The record** is `state.json` and `threads/<id>.json` under `~/.stratta`, each
  rewritten whole.
- **Shipping** runs `git add -A`, `git commit` and `git push` in the thread's folder
  with hooks enabled, then `gh`.
- **Stopping** is `thread.interrupt`, which asks the agent's session. Step 25 of
  `next.md` questions whether deleting a thread or stopping the daemon closes the
  session at all.

Already proposed elsewhere and not repeated here: the reproduction of an agent answering
another thread's request ([authority for an answer](../2026-11-25-delegated-authority/delegated-authority.md) Phase 0),
the same through the app ([composed surfaces](../2026-11-26-composed-surfaces/composed-surfaces.md) Phase 3), grants on
every answering path and narrowing (authority Phases 1 and 2), the caller checks
([pane threads](../2026-11-25-pane-threads-via-hooks/pane-threads-via-hooks.md), Safety), and the environment behaviour
([thread environments](../2026-11-25-thread-environments/thread-environments.md)). This plan uses them as rows in its
table and does not rebuild them.

## What is selected, and what is not

The selection is the drafting agent's proposal. Each line says why it was picked.

| Aspect | Selected | Why | Where |
| --- | --- | --- | --- |
| No control depends on the agent | Yes, as the test method | It is the assumption. A hostile scripted agent makes it checkable. | Phase 0 |
| Every concern accounted for in every plane | Yes, as a table | It is the operator's theory, and a table can show whether it was contrived. | Phase 0 |
| An approval drawn from the real parameters, by a route the agent cannot write to | Yes | The surface is Stratta's own subject, and the reference says least about it. | Phase 1; the route is the authority plan's |
| Writes to instruction, configuration and hook files are approved or held aside | Yes | No plan covers it, and the pane-threads plan depends on a hook. | Phase 2 |
| A record the agent cannot write | Yes | The decision-records plan stores records where the agent can rewrite them. | Phase 3 |
| Zones: the agent is somewhere the daemon is not | Yes, as a spike | The analysis concludes nothing else holds without it. | Phase 4 |
| A stop that does not need the agent | Yes | Small, and step 25 is already next to it. | Phase 5 |
| Authority that only narrows | Already planned | Authority plan, Phase 2. | Step 23 |
| A broker for credentials | Already planned | Thread environments, Phase 3. | Unscheduled |
| Every action traced to one trigger | Partly | Recording who sent a message is small and is added to Phase 1. The rest needs identity, which is outside Stratta. | Phase 1 |
| A journal of side effects, replayed on resume | No | Stratta does not run the agent's loop. For its own side effects (ship) it may be worth a plan of its own. | |
| Network limits, data-flow labels, supply chain | No | They belong to an environment and to the agent program. The table names their owner and stops. | Phase 0's table only |
| Attested workload identity | No | Design commitment 2 puts identity outside Stratta. | |
| The maturity score | No | See [the analysis](../../analysis/2026-11-26-habitat-and-stratta/habitat-and-stratta.md#cautions). | |

## Design

### 1. A hostile demo agent

A second scripted agent beside the demo agent, or a mode of it, that does one named
thing wrong when told to. It is a program running as the operator, which is exactly what
an agent's shell command is, so it needs no real agent and no model.

The behaviours, each switched on by name:

- `answer-other`: answer another thread's pending request through the socket.
- `answer-app`: the same through the app, with no browser.
- `say-one-do-another`: ask permission for one edit and write a different one.
- `no-ask`: write a file without asking.
- `protected-write`: write an instruction file, a git hook and an agent settings file.
- `rewrite-record`: change its own thread's transcript, and a decision record once
  there are any.
- `dress-up`: put control characters, bidirectional overrides and text shaped like an
  approval prompt into a request's title, a message, an option label and a thread title.
- `send-other`: put a message into another thread.
- `ship-self`: call `thread.ship` on its own thread.
- `read-secret`: read the grant secret, once step 16 of `next.md` has made one.
- `outlive`: ignore an interrupt, and keep running after its thread is deleted.

A new behaviour is added when a plan claims to have closed something.

### 2. Boundary tests, and the table they fill

One test for each behaviour, tagged so the set can be run alone. A test states what
happened, in the way the authority plan's Phase 0 does: where a hole is open, the test
asserts the hole, and the phase that closes it changes the assertion. Nothing is
skipped and nothing is marked as an expected failure, so the suite always says what is
true now.

The tests fill a table kept in this plan's Findings: Stratta's planes down the side
(execution, control, surface, record, configuration, outside; the analysis defines
them) and the concerns across. Every cell holds one of four things:

- a test, and whether the boundary holds;
- a plan that owns it, where one exists;
- an owner outside Stratta (the environment, the agent program, an identity layer);
- "not applicable", with the reason.

"Accounted for" means no cell is empty. It does not mean every boundary holds. The
table is also the check on the theory: if filling it turns up nothing that the plans
did not already have, that is worth knowing, and Findings should say so.

### 3. What is shown is what is asked

- A request keeps its raw input, as a tool call already does: the tool, the arguments,
  the paths.
- The app and the viewer draw a request from those: the path and the diff, or the
  command line, first. The agent's title is shown as the agent's wording and is not the
  heading.
- The controls are Stratta's and are fixed. Text from an agent, including an option
  label from [choice requests](../2026-11-26-choice-requests/choice-requests.md), is drawn as data and cannot occupy
  the place a control does. One function cleans agent text for every path in the
  terminal client, and removes what `clean/2` removes today.
- After an approved edit, the daemon compares the file with what the request said it
  would become. A difference becomes a notice on the thread and a field in the
  [decision record](../2026-11-25-decision-records/decision-records.md). This is a check after the fact and cannot
  prevent anything.
- A message into a thread records what sent it: the app, the client, or another
  thread's process where the caller checks can tell.

What this does not solve, stated so it is not claimed: an agent that can drive the
browser showing a view answers with that view's authority. Composed surfaces Design 7
says so already.

### 4. Protected paths: hold, check, exit

A list of paths that change how an agent, the daemon or the operator's tools behave:
instruction files, the agent program's settings and hooks, git hooks, and anything the
operator adds. The list is the operator's and lives in the data directory.

Three checks, in increasing strength:

- **Hold.** A request whose paths or diff touch the list is always put to the operator,
  whatever the thread's approval mode and whatever a rule would answer, and is drawn as
  touching a protected path.
- **Check.** At the end of each turn the daemon compares the listed paths with their
  state at the start. If one changed without a request, the thread pauses and Stratta
  raises a request of its own.
- **Exit.** Shipping looks at the diff against the base commit. If it includes a listed
  path, the commit waits for the operator. And the daemon stops running the
  repository's hooks itself when it commits and pushes, or asks first.

The first two work only as far as the agent reports what it does or leaves traces where
the daemon looks. The third is the one that would hold against an adversarial agent,
and only when the agent's files are in a different zone from the daemon. On one user
account it is a convenience.

### 5. A record with a chain, and a head kept elsewhere

- Each decision record carries the hash of the one before it. `stratta decisions
  --verify` walks the chain.
- A chain shows tampering only if its newest hash is somewhere the agent cannot write.
  The candidates on one machine: nowhere, under one user account; a file owned by
  another account; a collector on another host, through the exporter in
  [traces and measures](../2026-11-25-decision-telemetry/decision-telemetry.md). Phase 3 is a spike on which of these is
  real.

### 6. The second zone

The analysis's conclusion is that under this assumption the agent has to run somewhere
the daemon, the record and the surfaces are not. This plan does not build that. It asks
the cheapest question first: which of Phase 0's tests change when the agent is moved
and nothing else is.

Three zones to try, smallest first: a second user account on the same machine, with the
thread's folder shared; a container; a small virtual machine (Mjolnir, as
[thread environments](../2026-11-25-thread-environments/thread-environments.md) names it). For each: run the boundary
tests, record which change, and record what broke. The agent program's login is the
known obstacle and is that plan's Phase 0; the two belong in one sitting.

### 7. A stop that does not ask the agent

- A stop that ends the agent's processes from outside, by the daemon, without sending
  the agent anything it could ignore.
- After it, nothing the thread held can be used: its session is closed, and once grants
  exist, any grant issued for it is revoked.
- Step 25's two tests belong here in spirit and stay where they are.

## Phases

The sizes and the order are the drafting agent's estimates. Phase 0 needs nothing.
Everything after it can be reordered or dropped by the operator once Phase 0's table
exists.

### Phase 0: the table, measured (small to medium; needs nothing)

The hostile demo agent with the behaviours that need no later step, the boundary tests,
and the table written into Findings. No fix of any kind. It includes the two
reproductions that step 12 of `next.md` already asks for; if step 12 is done first, this
phase reuses them.

Then one paragraph in Findings on the experiment's question: what the table turned up
that no plan had.

### Phase 1: what is shown is what is asked (medium; needs nothing, better after step 9)

Design 3. Tests: `say-one-do-another` produces a notice and, after step 9 of `next.md`,
a field in the record; `dress-up` cannot produce a control character or a false control
on any surface; a message records its sender.

### Phase 2: protected paths (small to medium; needs nothing)

Design 4: the list, hold, check and exit. Tests: `protected-write` with a request is
held under every approval mode; without a request it pauses the thread at the end of
the turn; a ship that includes a listed path waits; a hook the agent wrote is not run by
the daemon without the operator's answer.

### Phase 3: the record's chain (small; needs step 9 of `next.md`; a spike decides the rest)

The chain and `--verify`. Then the spike on where the newest hash can be kept on one
machine and on two. Test: `rewrite-record` is detected when the head is out of reach,
and Findings says plainly that it is not when the head is not.

### Phase 4: the second zone (a spike; needs the operator's machine; with thread environments Phase 0)

Design 6. A table in Findings: each zone against each boundary test, and what broke.
The outcome is one of: a second user account is enough to be worth building on; only a
virtual machine is; or neither changes enough to matter on one machine, with the
reason. What follows is the operator's to decide.

### Phase 5: a stop from outside (small; near step 25 of `next.md`)

Design 7. Test: `outlive` is ended by the stop, and by deleting its thread.

## Not in scope

- A sandbox, an environment implementation, or a broker in this repository.
- Limits on the network, labels on data, or checks on what an agent installs.
- Identity for agents or for the operator. See design commitment 2.
- A score against Habitat's scale.
- A real agent that misbehaves. The hostile agent is scripted, and a test of what a
  model would actually attempt is a different experiment.
- Changing `next.md`. Where this goes in the order, and whether it goes anywhere, is the
  operator's decision.

## Open questions

- Are the six planes the right ones? They are the drafting agent's reading of the
  operator's sentence.
- Which agent is the assumption about: the model, steered by what it reads, inside an
  honest agent program; or the whole process? The first leaves the agent program's own
  permission check standing. The second leaves nothing standing on one user account.
  The tests assume the second, which is the harder case.
- Does the operator want requests held for protected paths even when he has chosen an
  approval mode that asks about nothing? Design 4 says yes.
- Should the daemon run a repository's hooks at all when it ships?
- If Phase 4 says a second zone is needed, does [thread environments](../2026-11-25-thread-environments/thread-environments.md)
  move from unscheduled to the front? `state.md` records the operator's decision either
  way.
- How does the surface show the operator which zone a thread is in, and which
  boundaries hold for it? This may be the first view that this plan adds.

## Findings

*To be filled in by Phase 0 (the table, and what it turned up), the Phase 3 spike and
the Phase 4 spike.*
