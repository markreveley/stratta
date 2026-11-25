---
type: handoff
updated: 2026-11-25
---

# Next

> This file's first open step is mirrored in direction's `repo-manifest.md`. Change it by asking an agent to run `update-next`. If you edit it by hand, run `update-next` afterwards.

## Next, in order

Two tracks meet here. The app-first plan came out of the operator's first day of use; the
control-plane plans came out of a design thread the same day. The order below puts the
control-plane foundation first — steps 2 to 5 are four small pieces that every later step
reads — and then returns to the app. Four places where the two tracks would otherwise
build the same thing twice are called out in the steps themselves.

1. **(operator)** Send the report from your first runs on your own machine (2026-11-25).
   The points that are still unknown here: which agent you ran and whether a real agent
   has been run at all; whether `mix setup` worked from Hex (it has only been built from
   local checkouts); whether ctrl-c and ctrl-s behave in `stratta attach` on your system;
   and how your terminal's tab shows a thread's status while `stratta attach` or
   `stratta watch` is open.
2. **(agent)** Phases 0 and 1 of [`plans/decision-records.md`](plans/decision-records.md):
   the hand-written record from a recorded thread that decides whether the evidence slot is
   derivable, then `Stratta.Decision`, its store, both times, and `stratta decisions`.
   Everything from step 3 on reads this record, and it is worth having alone — "why was
   `2a` approved, and how long did it wait?" cannot be answered today.
3. **(agent)** Phases 1 and 2 of
   [`plans/decision-telemetry.md`](plans/decision-telemetry.md): threads, turns and tool
   calls as OpenTelemetry spans with the OTLP exporter off by default, then the decision
   span and waiting time split into the agent's part and the operator's. Small, and it is
   what makes step 2 pay immediately.
4. **(agent)** Phase 0 then Phase 1 of
   [`plans/policy-as-actions.md`](plans/policy-as-actions.md): the go/no-go on taking
   `jido` as a dependency, then the rule set, the three shipped rules, and every automatic
   answer naming the rule that fired. This is the README's first next step and it
   supersedes Phase 3 of the pane-threads plan. Phase 2 (the same rules as Jido actions
   and a skill) only if Phase 0 says yes.
5. **(agent)** Phase 0 of
   [`plans/delegated-authority.md`](plans/delegated-authority.md): reproduce, as a test,
   an agent-run shell command approving another thread's pending request. Both the
   pane-threads plan and the app-first plan already work around this hole — the second one
   makes `source` refuse `approve` and `deny` lines because of it — so the test belongs in
   the suite before either of them relies on it being closed.
6. **(agent)** Phase 0 of [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md):
   describe every `Stratta.API` operation (arguments, result, one line, read-only or not),
   add `stratta ops`, and a test that fails when an operation has no spec. Moved ahead of
   the command bar on the app-first plan's own advice: with the specs in place, the
   parser's argument checks and the command bar's help come from them instead of being
   written twice, and the palette in step 12 draws on the same specs.
7. **(agent)** Phases 1 and 2 of [`plans/gui-first.md`](plans/gui-first.md): notifications
   and the tab title, the follow switch, then the command language in the daemon and the
   command bar in the app. Not blocked on anything; tested against the demo agent, with a
   look at notifications in a real browser.
8. **(agent)** Phases 1 to 3 of [`plans/slash-commands.md`](plans/slash-commands.md): keep
   the list of slash commands an agent advertises, add `stratta commands`, and suggest
   commands in the viewer's and the app's composer. Not blocked on anything; tested
   against the demo agent.
9. **(agent, blocked on operator)** Phase 0 of
   [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md): the spike that
   answers whether Claude Code still shows its own permission dialog while a
   `PermissionRequest` hook holds the request, and the six smaller questions listed
   there. It needs a session on a machine with Claude Code 2.1.295 or later, signed in.
   Write the findings into the plan's last section. In the same session, do Phase 4 of
   the slash-commands plan (what real agents advertise).
10. **(agent)** Phase 1 of the pane-threads plan: requests only (`stratta run`,
    `stratta hook`, `Stratta.PaneThread`), including the check that stops an agent from
    approving its own requests. Start only after step 9's findings are in. Then Phase 3 of
    the decision-records plan, so that a request raised through a hook produces the same
    record as a headless one and there is only ever one record type.
11. **(agent)** Phase 3 of the gui-first plan: the file list and the Markdown editor.
12. **(agent)** [`plans/behaviour-shaped-ui.md`](plans/behaviour-shaped-ui.md): Phase 1
    first (a parent thread id, the sidebar nested, the status dot rolled up from children),
    which is small and needed by step 17. Then Phases 2 and 3, the palette and what applies
    now — drawn on the command language from step 7 and the operation specs from step 6
    rather than on a second path of their own.
13. **(agent)** Phase 0 of [`plans/claim-graph.md`](plans/claim-graph.md): generate claim
    nodes from two or three real threads with structure only and no sentence from any model,
    and check them against the node format and validator the operator keeps elsewhere. A
    gate: if the structure alone is empty of interest, the commitment point is the wrong
    granularity and steps 14 and 15 do not happen. Then Phases 1 to 3 if it holds:
    thread-local claims, ancestry, the claims view, and promotion one claim at a time.
14. **(agent)** Phases 1 to 3 of
    [`plans/context-queries.md`](plans/context-queries.md): record what today's hand-off
    seed carries, then build a seed from claims under a size budget with the query
    recorded, then run the comparison through the evals harness the operator already has.
    The one number this track turns on: does a hand-off seeded with claims beat one seeded
    with the transcript at equal size? Write the result in whichever way it goes.
15. **(agent)** [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md): one OSC 8
    link primitive in `Stratta.TUI.Render`, then the links Stratta generates itself (PR
    URLs, diff file paths). Small, independent of everything else, and the width-accounting
    tests in Phase 1 are the part that matters.
16. **(agent)** [`plans/composer-editing.md`](plans/composer-editing.md): a wrapped,
    cursor-editable composer in the viewer, replacing the append-only single line. Do it
    after step 8, because both it and the slash-commands plan want the composer's arrow
    keys and the second one in should follow the first one's precedence rule.
17. **(agent, operator decides first)** Phases 1 and 2 of the delegated-authority plan (the
    unforgeable local grant, then narrowing), which is also the login the gui-first plan's
    Phase 4 requires before it opens a shell — one token, not two, and the grant is the
    more useful of the pair because it can also answer a request. Then the rest of gui-first
    Phase 4: the pseudo-terminal spike, the shell process, and `stratta shell`.
18. **(agent, operator decides first)** Phases 0 to 2 of
    [`plans/agent-approver.md`](plans/agent-approver.md): referral, the reviewer thread,
    reasons and reversal. Do not start step 17's authority work unless a reviewer is
    actually wanted — it is the feature that pays for it, and authority built without it is
    platform work. See the question below.
19. **(agent, blocked on operator)** Phase 0 of
    [`plans/remote-access.md`](plans/remote-access.md), the forwarding recipes, which are
    the two untested paths the gui-first plan names in its Design 8. Then Phase 5 of the
    gui-first plan: remote hosts over SSH, which needs two machines.

Not scheduled, and deliberately: Phase 0 of
[`plans/thread-environments.md`](plans/thread-environments.md) (the spike on how an agent
CLI's own login reaches a fresh environment) and its Phase 1, which are independent of
every step above and can run at any point; Phases 4 to 6 of the gui-first plan beyond what
steps 17 and 19 cover; Phase 4 of the policy plan (the assessment of letting a Jido runtime
own the thread); Phases 2 to 5 of the thread-environments plan; Phases 1 to 3 of the
remote-access plan; Phases 4 and 5 of the behaviour-shaped-UI plan; and Phase 3 of the
agent-approver plan. Each one depends on a finding that does not exist yet.

## Questions for the operator

- For pane threads, if holding a request blocks the pane, what should the default be:
  hold for a few seconds and then let the agent's own dialog take over, or hold until
  answered through Stratta? Undecided as of 2026-11-25. Step 9 tells whether the question
  arises at all, so it can wait for those findings.
- On a remote host, is `dev:2a` the right name for a request (host first, then slot and
  letter), or should slot numbers be shared across hosts so they stay unique? Needed
  before step 19, not before.
- Is the order above right? It was rearranged on 2026-11-25 to put the control-plane
  foundation (steps 2 to 5) ahead of the app work that the first day of use pointed at.
  The case for it: those four are small, none is blocked, every later step reads the
  decision record, and two of them remove work from the app-first plan rather than adding
  any — step 5 is the hole that makes `source` refuse `approve` lines, and step 6 is the
  specs its command parser would otherwise duplicate. The case against is simply that the
  app is where you were working. Steps 7, 8, 15 and 16 do not depend on steps 2 to 5 and
  can be pulled forward whole if you would rather carry on where you left off.
- The order also puts claims and context (steps 13 and 14) ahead of authority and a
  reviewer (17 and 18). Both need only the decision record. Claims first because it is
  cheaper, it is falsifiable in one session at step 13, and it takes no dependency in
  another language; authority is the larger commitment.
- Is a reviewer agent — a second thread answering some permission requests on your behalf,
  under a grant with an expiry — something you want? Step 18 and most of the authority plan
  exist only to make it safe. If the answer is no, both can wait indefinitely, and step 17
  shrinks to the login the app's shell needs.
- Is `jido` a dependency this project will take? Phase 0 of the policy plan answers the
  technical half (what it brings, whether it compiles, what `Jido.Harness.Plugin` starts
  when present). The other half is yours: rules as Jido actions is the README's first next
  step, and the larger version — a Jido runtime owning the thread instead of
  `ThreadServer` — is a re-fit of the timeline, the store, the slots and the socket API.

## State

- Everything is on `main` except the ten control-plane plans and this file's merged step
  list, which are on `stratta/claude-RQIiv1` until that branch is merged. The last code
  change is `85bc611` (slots, named requests, the current thread, the dashboard); every
  commit after it adds plans and this file.
- Three projects, one daemon: `core/` (threads, git, storage, control socket), `gui/`
  (LiveView; also runs the daemon), `tui/` (the `stratta` client: dashboard, viewer, diff
  view, one-shot commands).
- Threads sit in numbered slots; permission requests are named by slot and letter (`2a`);
  each workspace has a current thread kept by the daemon. `stratta watch` is the dashboard
  meant for a pane beside your shell.
- 46 tests pass (`mix test` in each of `core/`, `gui/`, `tui/`). They drive real
  `Jido.Harness` sessions, but only against the bundled demo agent, which is scripted and
  not a model.
- Not yet confirmed by a recorded run: real agents; installing dependencies from Hex; the viewer's
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
- Sixteen plans are written and not started. Six are the front-end and thread work:
  [`plans/gui-first.md`](plans/gui-first.md),
  [`plans/slash-commands.md`](plans/slash-commands.md),
  [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md),
  [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md),
  [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md) and
  [`plans/composer-editing.md`](plans/composer-editing.md). The last two are both terminal
  client only and both touch `Stratta.TUI.Render`; neither blocks anything.
- Ten more were added on 2026-11-25 from one design thread, in build order:
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
  session: the phase sizes are estimates, every Findings section is empty, and three open
  with a phase that can stop the plan — the claim-graph pilot, the environment login
  spike, and the policy plan's go/no-go on `jido`.
- The through-line of those ten, in one sentence: a permission request is the one moment a
  thread already pauses with a proposal, its grounds, and somebody to rule on it, so making
  that moment a record is what the policy, measurement, claim, authority and reviewer work
  all build on.
- Where the two tracks meet, settled on 2026-11-25 rather than left to a merge: the
  app-first plan's command language is the mechanism the behaviour-shaped-UI palette
  renders, not a second path; its Phase 4 login and the authority plan's local grant are
  one token; its Design 8 answers the thread-environments plan's open question, which was
  whether a daemon runs per host or one daemon drives remote folders (per host); and its
  Design 1, everything through `Stratta.API`, is what the remote-access plan's second
  listener needs.
- Direction (2026-11-25, after the operator's first day of use): the app is the main
  front end and gains what the terminal client has (commands, a shell, status through
  notifications) plus files and remote hosts. The terminal client stays as the second
  front end on the same daemon and the same command language.
- The app calls the core's modules directly; only the terminal client goes through
  `Stratta.API` and the socket. New app features are to be written as `Stratta.API`
  operations, so that the app can later drive a daemon on another machine.
- The operator has run Stratta on their own machine, in the terminal and in the app
  (2026-11-25). Details are not recorded yet; see step 1.

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
