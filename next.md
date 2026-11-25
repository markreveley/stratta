---
type: handoff
updated: 2026-11-25
---

# Next

> This file's first open step is mirrored in direction's `repo-manifest.md`. Change it by asking an agent to run `update-next`. If you edit it by hand, run `update-next` afterwards.

## Next, in order

1. **(agent)** Run `update-next`. The steps below were edited by hand on 2026-11-25, so
   direction's `repo-manifest.md` may no longer mirror this file's first open step. Do it
   before acting on anything else here, and before editing this list again. Ten more plans
   were added to the list later the same day by an agent that could not run `update-next`
   (it is not available in its session), so the mirror is still out of date.
2. **(operator)** Run Stratta on your own machine with a real agent. Nothing here has been
   run against one yet. With Elixir 1.19+ on OTP 28+ installed: `cd gui && mix setup &&
   mix phx.server`, then `cd tui && mix setup` and put `tui/stratta` on your PATH. In a
   git repository run `stratta agents` to see which agents are ready, then
   `stratta new -a claude --attach "say hello"`. Note whether `mix setup` worked from Hex
   (it has only been built from local checkouts), and whether your terminal's tab shows
   the thread's status while `stratta attach` or `stratta watch` is open.
3. **(agent)** Phases 1 to 3 of [`plans/slash-commands.md`](plans/slash-commands.md): keep
   the list of slash commands an agent advertises, add `stratta commands`, and suggest
   commands in the viewer's and the app's composer. Not blocked on anything; tested
   against the demo agent.
4. **(agent, blocked on operator)** Phase 0 of
   [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md): the spike that
   answers whether Claude Code still shows its own permission dialog while a
   `PermissionRequest` hook holds the request, and the six smaller questions listed
   there. It needs a session on a machine with Claude Code 2.1.295 or later, signed in.
   Write the findings into the plan's last section. In the same session, do Phase 4 of
   the slash-commands plan (what real agents advertise).
5. **(agent)** Phase 1 of the pane-threads plan: requests only (`stratta run`,
   `stratta hook`, `Stratta.PaneThread`), including the check that stops an agent from
   approving its own requests. Start only after step 4's findings are in.

6. **(agent)** Phase 0 of [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md):
   describe every `Stratta.API` operation (arguments, result, one line, read-only or not),
   add `stratta ops`, and a test that fails when an operation has no spec. Useful on its
   own as reference; the later phases (a sandbox where an orchestrating model writes code
   against Stratta) wait until there is an orchestrating model.

7. **(agent)** [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md): one OSC 8
   link primitive in `Stratta.TUI.Render`, then the links Stratta generates itself (PR
   URLs, diff file paths). Small, independent of everything else, and the width-accounting
   tests in Phase 1 are the part that matters.
8. **(agent)** [`plans/composer-editing.md`](plans/composer-editing.md): a wrapped,
   cursor-editable composer in the viewer, replacing the append-only single line. Do it
   after step 3, because both it and the slash-commands plan want the composer's arrow
   keys and the second one in should follow the first one's precedence rule.

9. **(agent)** Phases 0 and 1 of [`plans/decision-records.md`](plans/decision-records.md):
   the hand-written record from a recorded thread that decides whether the evidence slot is
   derivable, then `Stratta.Decision`, its store, both times, and `stratta decisions`.
   Everything from here to step 17 reads this record, so it is the foundation and it is
   also worth having alone — "why was `2a` approved, and how long did it wait?" cannot be
   answered today. Unblocked, but better after step 5, so that one record type covers
   requests from headless and pane threads both.
10. **(agent)** Phases 1 and 2 of
    [`plans/decision-telemetry.md`](plans/decision-telemetry.md): threads, turns and tool
    calls as OpenTelemetry spans with the OTLP exporter off by default, then the decision
    span and waiting time split into the agent's part and the operator's. Small, and it is
    what makes step 9 pay immediately.
11. **(agent)** Phase 0 then Phase 1 of
    [`plans/policy-as-actions.md`](plans/policy-as-actions.md): the go/no-go on taking
    `jido` as a dependency, then the rule set, the three shipped rules, and every automatic
    answer naming the rule that fired. This is the README's first next step and it
    supersedes Phase 3 of the pane-threads plan. Phase 2 (the same rules as Jido actions
    and a skill) only if Phase 0 says yes.
12. **(agent)** Phase 0 of
    [`plans/delegated-authority.md`](plans/delegated-authority.md): reproduce, as a test,
    an agent-run shell command approving another thread's pending request. The pane-threads
    plan already documents this hole and plans two checks against it; this is the test those
    checks have to keep failing. Pull it forward into step 4 or 5's session if that is
    convenient — it belongs with that work and needs nothing from steps 9 to 11.
13. **(agent)** Phase 0 of [`plans/claim-graph.md`](plans/claim-graph.md): generate claim
    nodes from two or three real threads with structure only and no sentence from any model,
    and check them against the node format and validator the operator keeps elsewhere. A
    gate: if the structure alone is empty of interest, the commitment point is the wrong
    granularity and steps 15 and 16 do not happen.
14. **(agent)** Phase 1 of
    [`plans/behaviour-shaped-ui.md`](plans/behaviour-shaped-ui.md): a parent thread id on
    the thread record, the sidebar nested, the status dot rolled up from children. Small,
    independent, and needed by step 17 before a reviewer can be a child of the thread it
    serves. The rest of that plan waits on step 6 (code mode Phase 0, which produces the
    operation specs the palette is drawn from) and on step 3.
15. **(agent)** Phases 1 to 3 of the claim-graph plan: thread-local claims written with
    every decision record, ancestry within the thread, the claims view, and promotion one
    claim at a time into the operator's own collection. Only after step 13 holds.
16. **(agent)** Phases 1 to 3 of
    [`plans/context-queries.md`](plans/context-queries.md): record what today's hand-off
    seed carries, then build a seed from claims under a size budget with the query
    recorded, then run the comparison through the evals harness the operator already has.
    The one number this whole track turns on: does a hand-off seeded with claims beat one
    seeded with the transcript at equal size? Write the result in whichever way it goes.
17. **(agent, operator decides first)** Phases 1 and 2 of the delegated-authority plan (the
    unforgeable local grant, then narrowing), then Phases 0 to 2 of
    [`plans/agent-approver.md`](plans/agent-approver.md) (referral, the reviewer thread,
    reasons and reversal). Do not start the authority work unless a reviewer is actually
    wanted — it is the feature that pays for it, and authority built without it is platform
    work. See the question below.
18. **(agent, operator decides first)** Phase 0 of
    [`plans/thread-environments.md`](plans/thread-environments.md): the spike on how each
    agent CLI's own login reaches a fresh environment, survives a checkpoint, and survives
    being restored twice. It gates that whole plan, and the plan is independent of steps 9
    to 17, so it can run at any point. Phase 1 (extract `Stratta.Environment`, implement it
    with today's local code, change nothing visible) is safe to do whatever the spike says.
19. **(agent)** Phase 0 of [`plans/remote-access.md`](plans/remote-access.md): the
    port-forwarding and socket-forwarding recipes in `docs/`, with what each one does and
    does not protect. Documentation only, unblocked, and it may be all that is needed —
    which is the reason to write it before the later phases are built for the wrong reason.

Not scheduled, and deliberately: Phases 2 to 5 of the behaviour-shaped-UI plan, Phase 4 of
the policy plan (the assessment of letting a Jido runtime own the thread), Phases 2 to 5 of
the thread-environments plan, Phases 1 to 3 of the remote-access plan, and Phase 3 of the
agent-approver plan. Each one depends on a finding that does not exist yet.

## Questions for the operator

- For pane threads, if holding a request blocks the pane, what should the default be:
  hold for a few seconds and then let the agent's own dialog take over, or hold until
  answered through Stratta? Undecided as of 2026-11-25. Step 3 tells whether the question
  arises at all, so it can wait for those findings.
- Which track comes after the foundation (steps 9 to 11): claims and context, or authority
  and a reviewer? Both need only the decision record. The recommendation is claims first:
  it is cheaper, it is falsifiable in one session at step 13, and it takes no dependency in
  another language. Authority is the larger commitment and should wait until a reviewer is
  genuinely wanted.
- Is a reviewer agent — a second thread answering some permission requests on your behalf,
  under a grant with an expiry — something you want? Step 17 and most of the authority plan
  exist only to make it safe. If the answer is no, both can wait indefinitely and nothing
  else in the list is affected.
- Is `jido` a dependency this project will take? Phase 0 of the policy plan answers the
  technical half (what it brings, whether it compiles, what `Jido.Harness.Plugin` starts
  when present). The other half is yours: rules as Jido actions is the README's first next
  step, and the larger version — a Jido runtime owning the thread instead of
  `ThreadServer` — is a re-fit of the timeline, the store, the slots and the socket API.
- For thread environments, does the daemon stay on your machine and drive a remote
  environment, or does a daemon run inside each one? The first keeps the control socket's
  trust model exactly as it is; the second is what makes a thread survive the laptop
  closing. It changes everything downstream in that plan and does not need answering until
  step 18's spike is done.

## State

- Everything is committed and pushed on `main`; there are no other branches. The last
  code change is `85bc611` (slots, named requests, the current thread, the dashboard).
  The commits after it add the plans and this file.
- Three projects, one daemon: `core/` (threads, git, storage, control socket), `gui/`
  (LiveView; also runs the daemon), `tui/` (the `stratta` client: dashboard, viewer, diff
  view, one-shot commands).
- Threads sit in numbered slots; permission requests are named by slot and letter (`2a`);
  each workspace has a current thread kept by the daemon. `stratta watch` is the dashboard
  meant for a pane beside your shell.
- 46 tests pass (`mix test` in each of `core/`, `gui/`, `tui/`). They drive real
  `Jido.Harness` sessions, but only against the bundled demo agent, which is scripted and
  not a model.
- Not yet verified anywhere: real agents; installing dependencies from Hex; the viewer's
  ctrl-c and ctrl-s handling on macOS (it relies on `ps` and `stty` and was run on Linux
  only); how a terminal that draws OSC 7501 presents the dashboard's per-thread records.
- [`docs/app-and-terminal.md`](docs/app-and-terminal.md) maps every task onto both front
  ends.
- Decision (2026-11-24): nothing in this repository, files or commit messages, names a
  product other than Jido and the agents Stratta runs. Terminal-specific glue (window
  layouts, status-line hooks) is kept outside it on purpose; the client only offers the
  neutral hooks `STRATTA_OPENER` and `STRATTA_STATUS_HOOK`. Keep new work to that rule.
- Decision (2026-11-25): open standards and wire formats are not products, so they may be
  named. In the plans that means OpenTelemetry and OTLP, Biscuit, Ed25519 and TPM 2.0,
  OpenID Connect and WebAuthn, QUIC, and CloudEvents. The rule above still holds for
  products, including the implementations of those standards: each stays a behaviour with a
  local implementation, with the named backend configured in from outside.
- Fifteen plans are written and not started. The five from 2026-11-24 and 25 are the
  near-term front-end and thread work: [`plans/slash-commands.md`](plans/slash-commands.md),
  [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md),
  [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md),
  [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md) and
  [`plans/composer-editing.md`](plans/composer-editing.md). The last two are both terminal
  client only and both touch `Stratta.TUI.Render`; neither blocks anything.
- Ten more were added on 2026-11-25 from one design conversation, in build order:
  [`plans/decision-records.md`](plans/decision-records.md),
  [`plans/decision-telemetry.md`](plans/decision-telemetry.md),
  [`plans/policy-as-actions.md`](plans/policy-as-actions.md),
  [`plans/behaviour-shaped-ui.md`](plans/behaviour-shaped-ui.md),
  [`plans/claim-graph.md`](plans/claim-graph.md),
  [`plans/context-queries.md`](plans/context-queries.md),
  [`plans/delegated-authority.md`](plans/delegated-authority.md),
  [`plans/agent-approver.md`](plans/agent-approver.md),
  [`plans/thread-environments.md`](plans/thread-environments.md) and
  [`plans/remote-access.md`](plans/remote-access.md). They have not each had a design
  session: the phase sizes are estimates, every Findings section is empty, and three of
  them open with a phase that can stop the plan — the claim-graph pilot, the environment
  login spike, and the policy plan's go/no-go on `jido`. They were written to the two naming
  decisions above: they name open standards where that helps an implementer and no
  products, so every external dependency is a behaviour with a local implementation.
- The through-line of those ten, in one sentence: a permission request is the one moment a
  thread already pauses with a proposal, its grounds, and somebody to rule on it, so making
  that moment a record is what the policy, measurement, claim, authority and reviewer work
  all build on.

## Environment facts

- Elixir 1.19+ on Erlang/OTP 28+ (the terminal client uses OTP 28's raw mode). Also needs
  `git`, a C++17 compiler and `make`, Python 3 for the demo agent, and `gh` for pull
  requests.
- Do not run as root: Harness' native process helper refuses to.
- One daemon per data directory (`~/.stratta`, or `STRATTA_DATA_DIR`). A second one
  refuses to start.
- `STRATTA_VENDOR_DEPS=/path/to/checkouts` builds offline from local dependency
  checkouts; see `vendored_deps/1` in each `mix.exs`.
- The agent's slash commands, per-agent session options and steering all depend on what
  each agent's protocol mode offers; the demo agent supports steering and model switching
  only.
- `tui/` tests start a real daemon in the test VM (`core/` is a test-only dependency) and
  talk to it over the socket. All of them share one workspace, so slot numbers in a test
  run are not small; do not assert on single-digit slots.
- OTP's raw mode leaves the terminal's signal and flow-control keys on. The viewer turns
  them off with `stty`, run against the terminal device named by `ps -o tty=`, because
  child processes of the BEAM have no controlling terminal and cannot open `/dev/tty`.
- A BEAM program cannot hand its terminal to a child process. Anything that must run an
  agent's own interface in the pane needs a shell launcher that `exec`s it.
- To exercise the views for real, drive `tui/stratta` through a pseudo-terminal as a
  normal user (a script that forks a pty, sets its size, sends keys and feeds the output
  to a terminal emulator library). `su -c` detaches the controlling terminal and gives
  misleading results.
- `Jido.Harness` passes session updates it does not interpret through as provider events
  of kind `acp_update`; `Stratta.Timeline` is where to pick them up.
