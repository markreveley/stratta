---
type: handoff
updated: 2026-11-27
---

# State

> What is true now, and nothing else: no history (git has it) and no next steps (`next.md`). `/end` rewrites this file (repo-template R30).

## Now

- Nothing in `next.md` is built. One thing outside it is: a timeline item's id is counted
  per thread and carried across a restart of the daemon, with two tests
  ([`md/plans/2026-11-26-event-log/event-log.md`](md/plans/2026-11-26-event-log/event-log.md), Phase 1). It is tested only by itself.
  `core/test/timeline_test.exs` and a restart check pass with `timeline.ex` loaded
  alone, beside a stand-in for the Harness event struct, on Elixir 1.14.0 with
  Erlang/OTP 25. `mix test` has not been run on the versions Stratta requires since the
  change. Running it is part of step 1.
- The rest of the newest work is plans and documents only:
  `md/docs/design-commitments.md`, `md/docs/operator.md`, the plans `composed-surfaces`,
  `choice-requests` and `per-request-context`, and a `kind` and a *Why this exists*
  section in every plan; [`md/analysis/2026-11-26-habitat-and-stratta/habitat-and-stratta.md`](md/analysis/2026-11-26-habitat-and-stratta/habitat-and-stratta.md),
  an analysis of Replit's Agent Habitat architecture against this repository, and the
  plan [`adversarial-boundaries`](md/plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md) that follows from it;
  and the plans [`event-log`](md/plans/2026-11-26-event-log/event-log.md) and [`graphs`](md/plans/2026-11-26-graphs/graphs.md), with
  sentences in seven other plans that point at them.
- A thread whose timeline was damaged by repeated ids before that change keeps the
  damage. Loading it gives every item its own id and repairs nothing else.
- The operator's working assumption: agents are adversarial, and every concern should be
  accounted for in every plane of Stratta. He holds it as possibly wrong or contrived.
  It is quoted in the Habitat analysis and in the adversarial-boundaries plan, and the
  order of `next.md` does not depend on it.
- Nothing has been run against the direction. Unverified, and all part of step 1: that
  a LiveView page behaves inside terminal-browser; how Rex shows Stratta's OSC 7501
  reports; that terminal-browser's `--split` works inside Rex.
- Read and not run: terminal-browser and PixelGUI (source at `690f59f`); Rex and QIP
  (their sites and third-party write-ups only); Claude Code's print mode (from memory);
  Replit's Agent Habitat white paper and its advisory on managed cloud environments
  (through a summarising tool, not in full); Jido's flows, durable runs, topology and
  blackboard (`14424fe`); Reactor (`7b4134c`), Runic (`0c15a9c`) and Journey
  (`fe8e90d`).
- Read from the code at `419ebb9` and not run, listed in the adversarial-boundaries
  plan under *What exists today*: a request is drawn from the agent's own title and
  diff; the socket and the app answer any caller; the daemon runs the repository's git
  hooks when it commits and pushes.
- Whether a real agent has been run in Stratta at all is not known here.
- The tutorial on this repository is in `md/docs/tutorial/`: seven parts, 40 sections, a
  glossary and seven labs. Each step in `next.md` links to the sections to read first,
  and the tutorial no longer keeps a table of steps. Run against the current code and
  passing: its excerpt check, its site check, `check_next.py`, and its restart check
  (the last on Elixir 1.14.0). It describes the code as of `a7c451f`, with the later
  additions its Sources section lists, and it names the plans by their old paths under
  `plans/`. It holds no step numbers: its source names a step by a key and the number
  is looked up in `next.md` when the pages are built, so after a step is added or moved
  it needs `make_diagrams.py` and `build.py` run again, and `check_next.py` says so.
  Its open items are steps 28 and 29.
- The method for building Stratta is PropertyDamage's, whole, by the operator's decision
  ([the plan](md/plans/2026-11-28-adopt-propertydamage-method/adopt-propertydamage-method.md),
  accepted; the analyses behind it are
  [borrowing](md/analysis/2026-11-27-borrowing-property-damage/borrowing-property-damage.md)
  and [the comparison](md/analysis/2026-11-27-methods-compared/methods-compared.md)).
  In place: its evidence rules and the gate, in `AGENTS.md`; OpenSpec 2.2.0 initialised
  at the root, with its project context written and no spec yet. Not in place: anything
  that runs the gate on a push, a pinned toolchain, credo, the timeline's spec, the
  library, a second reader. The earlier verification plan is dropped. It has not been
  checked that a session lists OpenSpec's skills, which are in `.agents/skills/` with
  links from `.claude/skills/`.
- A spike on the timeline, before the method was chosen.
  Run, on `timeline.ex` by itself on Elixir 1.14.0: fourteen rules as generated tests,
  of which eleven hold and three fail; a stream of malformed events, on which the fold
  raises at three lines; and 85 seeded bugs, of which the existing tests and the
  generated ones together catch 52 of the 81 that compile. The findings are the three
  files in [`md/issues/`](md/issues/README.md), all open. The scripts are in
  `md/analysis/2026-11-27-verification-design/spike/`; `run.sh` runs them. None of it
  has been run in a daemon or on the versions Stratta requires.
- PropertyDamage has been read and not run
  ([the analysis](md/analysis/2026-11-27-property-damage/property-damage.md)). Its docs
  on HexDocs describe two features its `main` has removed. Its repository runs the
  OpenSpec tool, pins Elixir 1.20.1 on Erlang/OTP 27.3.4, and ships a skill that
  interviews the user and generates a model.
- Decisions that wait on the operator: steps 4 to 7, each with an analysis written to be
  decided without the code; step 30, on comments; and steps 26 and 27.
- There are five design commitments. The fifth, no comments in the code, is newer than
  the code, which has 161 comment lines and 87 documentation attributes
  ([the issue](md/issues/2026-11-28-code-comments.md)).
- The layout is repo-template's, synced at the commit in
  [`md/docs/repo-template-sync.md`](md/docs/repo-template-sync.md), and its check
  passes. `openspec/` at the root is the one declared exception to it. The design commitments
  are in `md/docs/`; whether they become a governing document is step 27. The repo has no `LICENSE`.
- git: everything is committed and pushed on `main`. The other branches on the remote,
  `graphs-and-event-log` among them, hold nothing that is not on `main`.

### The direction, and how to read `next.md`

Steps 2 to 7 are about how Stratta is verified and sit ahead of the rest by the
operator's direction. For the others, the order of `next.md` is the dependency graph: each step comes after everything it needs and nowhere
later. Where two steps do not constrain each other, the operator's direction decides. The
direction: the operator's host terminal, Rex first, is the environment, and Stratta is a
guest in it ([`md/plans/2026-11-26-composed-surfaces/composed-surfaces.md`](md/plans/2026-11-26-composed-surfaces/composed-surfaces.md)). An agent's own
interface runs in a pane, and views that the operator or an agent opens sit beside it.
The app is taken apart into views, each a page that draws one thing, shown in a pane by
terminal-browser and bound to the daemon's state. The app as the place the operator
lives (its command bar, file editor, shell and list of hosts) waits, and is listed below.

Each step carries its kind, as [design commitments](md/docs/design-commitments.md) defines
them: a **need** is something observed in use or a fact in the code; an **experiment** is
a question to look into; an **exploration** is built because the operator wants to try
the idea. The label describes a step and does not rank it. The order, the phases and any
limit in the plans are suggestions drafted by agents; the operator decides
([operator.md](md/docs/operator.md)). Nothing here has been used in real work yet, so after
steps 1 to 10 it is worth the operator looking over the rest of the list again.

### Not scheduled

Not scheduled, by the operator's decision: the reviewer agent, all of
[`md/plans/2026-11-25-agent-approver/agent-approver.md`](md/plans/2026-11-25-agent-approver/agent-approver.md). The operator finds requests from
coding agents appropriate and informative. It may return if unattended work changes
that. It would need steps 11, 19 and 23.

Follow-up, not scheduled: the app as an environment. [`md/plans/2026-11-25-gui-first/gui-first.md`](md/plans/2026-11-25-gui-first/gui-first.md)
Phases 1 to 6 (notifications and following, the command language and the command bar, the
files panel and the Markdown editor, the login and the shell in a web page, remote hosts,
scripts), Phase 3 of the slash-commands plan (suggestions in the app's composer), and
Phases 2 and 3 of the behaviour-shaped-UI plan (the palette, which that plan builds on
the app-first plan's command language). They return once the host-terminal direction has
been used (what counts as used is the operator's to say), and the first reason to return is to test that direction against a front end
that hosts everything itself. Three parts of the app-first plan are not waiting: its
Design 1, everything the app does going through `Stratta.API`, is what step 13's protocol
document assumes of every client; its protocol version is built in step 13; and its login
is the grant in step 16. Also unscheduled, until a reason is met in use: Phases 5 and 6
of the composed-surfaces plan, a view that is not a page and the spike on a guest inside
the viewer.

Not scheduled: [`md/plans/2026-11-25-thread-environments/thread-environments.md`](md/plans/2026-11-25-thread-environments/thread-environments.md), because
nothing in the graph depends on it. It never blocks anything, so it can run whenever it is
wanted, starting with its Phase 0 spike on how an agent CLI's own login reaches a fresh
environment and its Phase 1, which extracts the behaviour and changes nothing visible.
The Habitat analysis argues that under the adversarial assumption most boundaries cannot
hold unless a thread runs somewhere the daemon does not, which would put this plan in
front of others. That is an argument, not a decision.

Not scheduled, waiting on the operator: [`md/plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md`](md/plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md).
Whether it enters `next.md`, and where, is step 26, the operator's. Its Phase 0 needs nothing: a
scripted agent that misbehaves on purpose, and tests that record which boundaries hold
today, with no fixes. It includes step 12's two reproductions and reuses them if step 12
is done first. Its Phase 4 spike belongs in the same sitting as Phase 0 of the
thread-environments plan.

Every other phase of every plan, each waiting on a finding or a decision that does not
exist yet: Phases 1 to 4 of the code-mode plan, which wait for an orchestrating model;
Phases 2 and 4 of the pane-threads plan, its Phase 3 being superseded by step 11; Phase 4 of
the policy plan, the assessment of letting a Jido runtime own the thread; Phases 3 and 4 of
the telemetry plan, which need their measures defined tightly enough to test; Phases 4 and
5 of the behaviour-shaped-UI plan; Phase 4 of the claim-graph plan and Phases 4 and 5 of
the context-queries plan, which wait on step 21's result; Phases 3 and 4 of the
delegated-authority plan, the external verifier and signed answers; Phase 4 of the choice-requests plan, the declared space, which waits
on step 22; Phases 1 to 3 of the remote-access plan, which wait on step 24; Phases 2 to 4
of the event-log plan, the file of events, which wait on what step 9's Phase 0 says an
evidence id should point at; and Phases 1 to 3 of the graphs plan (a thread's outcome
and a check, a first graph of two threads written by hand, and the choice of how graphs
are run), which wait on its Phase 0 in step 11 and on the operator.

## Environment facts

- Stratta needs Elixir 1.19 and Erlang/OTP 28.
- A cloud session can install Elixir 1.14.0 with Erlang/OTP 25 at most and cannot reach
  the Hex registry, so it cannot run the suite. `core/lib/stratta/timeline.ex` loads by
  itself there beside a stand-in for `Jido.Harness.Event`; the tutorial's
  `md/docs/tutorial/scripts/check_timeline_ids.sh` does that across two lifetimes of the
  virtual machine.
  It can clone public repositories from GitHub, so StreamData and Jason compile there
  from their checkouts with `elixirc`, and the spike's `run.sh` runs generated tests and
  the existing `timeline_test.exs` against `timeline.ex` with no Mix.
- To rebuild the tutorial after editing `md/docs/tutorial/source/`: `pip install markdown`,
  then `python3 scripts/build.py` and `python3 scripts/check_site.py` from its folder.
  Its README lists the other scripts.
- OpenSpec is a Node program: `npm install -g @fission-ai/openspec` works in a cloud
  session. Its folder is `openspec/` at the root.
- Elixir 1.20 needs Erlang/OTP 27 or later. Harness's CI tests Elixir 1.19 on OTP 28 and
  Elixir 1.20 on OTP 29. PropertyDamage's `main` needs Elixir 1.17 or later.
- The app listens on `127.0.0.1:4001` (`PORT` overrides). The socket is
  `~/.stratta/stratta.sock` (`STRATTA_SOCKET` overrides).
- The opener and the status hook are `STRATTA_OPENER` and `STRATTA_STATUS_HOOK`: shell
  commands of the operator's, which is where anything specific to Rex belongs.
- terminal-browser needs a terminal with the kitty graphics protocol, and sends usage
  telemetry unless `terminal-browser config set telemetry.usage off` is run.
- Rex is in a closed beta; its macOS app is the only desktop client so far.
