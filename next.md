---
type: handoff
updated: 2026-11-25
---

# Next

> This file's first open step is mirrored in direction's `repo-manifest.md`. Change it by asking an agent to run `update-next`. If you edit it by hand, run `update-next` afterwards.

## Next, in order

The order is the dependency graph: each step comes after everything it needs and nowhere
later. Where two steps do not constrain each other, the preference from the operator's
first day of use decides, which is why the app's files panel and its shell sit as early as
they do. One consequence worth naming: the shell arrives at step 10 rather than near the
end, because the login it needs turned out to be the authority plan's first phase, which is
small and has only step 2 in front of it.

1. **(operator)** Send the report from your first runs on your own machine (2026-11-25).
   The points that are still unknown here: which agent you ran and whether a real agent
   has been run at all; whether ctrl-c and ctrl-s behave in `stratta attach` on your
   system; and how your terminal's tab shows a thread's status while `stratta attach` or
   `stratta watch` is open. Hex is no longer one of them; see the lock files in State.
2. **(agent)** Phases 0 to 2 of [`plans/decision-records.md`](plans/decision-records.md):
   the hand-written record from a recorded thread that decides whether the evidence slot is
   derivable, then `Stratta.Decision`, its store, both times and `stratta decisions`, then
   the evidence — the ids of the timeline events between the start of the turn and the
   request. The root of the graph: steps 3, 4, 9 and 15 all read this record, and Phase 2
   in particular is where step 15's claims get their grounds, so it is not optional to that
   track. Worth having alone, because "why was `2a` approved, and how long did it wait?"
   cannot be answered today.
3. **(agent)** Phases 1 and 2 of
   [`plans/decision-telemetry.md`](plans/decision-telemetry.md): threads, turns and tool
   calls as OpenTelemetry spans with the OTLP exporter off by default, then the decision
   span and waiting time split into the agent's part and the operator's. Phase 1 needs
   nothing; Phase 2 needs step 2. Small, and it is what makes step 2 pay immediately.
4. **(agent)** Phase 0 then Phase 1 of
   [`plans/policy-as-actions.md`](plans/policy-as-actions.md): the go/no-go on taking
   `jido` as a dependency, then the rule set, the three shipped rules, and every automatic
   answer naming the rule that fired. Phase 0 needs nothing; Phase 1 needs step 2, so that
   an automatic answer is recorded with its rule. This is the README's first next step and
   it supersedes Phase 3 of the pane-threads plan. Phase 2 (the same rules as Jido actions
   and a skill) only if Phase 0 says yes; Phase 3 ("always allow this", which appends a rule
   and says which one it appended) follows Phase 1 whenever it is wanted. Two facts for
   Phase 0, read from the Jido repository at `14424fe` and not yet from a build: its `main`
   is `3.0.0-beta.3`, a beta that merges four packages into one, so its required
   dependencies include an HTTP client and a language-model client that rules would never
   call; and what the plan calls a skill is a `Jido.Plugin` there (in that version a skill
   is a loader for `SKILL.md` files), so Phase 2's wording changes with it.
5. **(agent)** Phase 0 of
   [`plans/delegated-authority.md`](plans/delegated-authority.md): reproduce, as a test,
   an agent-run shell command approving another thread's pending request. Needs nothing,
   and two plans already work around this hole — the app-first plan makes `source` refuse
   `approve` and `deny` lines because of it — so the test belongs in the suite before
   either of them relies on it being closed.
6. **(agent)** Phase 0 of [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md):
   describe every `Stratta.API` operation (arguments, result, one line, read-only or not),
   add `stratta ops`, and a test that fails when an operation has no spec. Needs nothing,
   and two later steps need it: the command parser in step 7 takes its argument checks and
   its help from these specs instead of restating them, and so does the palette in step 14.
7. **(agent)** Phases 1 and 2 of [`plans/gui-first.md`](plans/gui-first.md): notifications
   and the tab title, the follow switch, then the command language in the daemon and the
   command bar in the app. Phase 1 needs nothing and can move anywhere; Phase 2 is the one
   that wants step 6 first. Tested against the demo agent, with a look at notifications in
   a real browser.
8. **(agent)** Phase 3 of the gui-first plan: the file list and the Markdown editor, with
   the path checks and the content hash that stop a save from overwriting what the agent
   has just changed. Needs nothing; placed here because it was wanted early.
9. **(agent)** Phase 1 of the delegated-authority plan: the behaviour, the unforgeable
   local grant, a grant on every answering path, the grant id in the decision record, and
   step 5's reproduction now refused. Needs steps 2 and 5. It is also the login the
   gui-first plan's Phase 4 requires before it opens a shell in a web page — one token, not
   two, and the grant is the more useful of the pair, because a session that can be checked
   against what it may do can also answer a request.
10. **(agent)** Phase 4 of the gui-first plan: the pseudo-terminal spike listed there, then
    the shell process in `core/`, its operations and subscription, the terminal widget in
    the app, and `stratta shell`. Needs step 9 for the login. The spike itself needs
    nothing and can be done earlier if a reason appears.
11. **(agent)** Phases 1 to 3 of [`plans/slash-commands.md`](plans/slash-commands.md): keep
    the list of slash commands an agent advertises, add `stratta commands`, and suggest
    commands in the viewer's and the app's composer. Needs nothing; steps 14 and 17 need
    its precedence rule.
12. **(agent, blocked on operator)** Phase 0 of
    [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md): the spike that
    answers whether Claude Code still shows its own permission dialog while a
    `PermissionRequest` hook holds the request, and the six smaller questions listed
    there. It needs a session on a machine with Claude Code 2.1.295 or later, signed in.
    Write the findings into the plan's last section. In the same session, do Phase 4 of
    the slash-commands plan (what real agents advertise).
13. **(agent)** Phase 1 of the pane-threads plan: requests only (`stratta run`,
    `stratta hook`, `Stratta.PaneThread`), including the check that stops an agent from
    approving its own requests. Needs step 12's findings. Then Phase 3 of the
    decision-records plan, so that a request raised through a hook produces the same record
    as a headless one and there is only ever one record type.
14. **(agent)** [`plans/behaviour-shaped-ui.md`](plans/behaviour-shaped-ui.md): Phase 1
    first (a parent thread id, the sidebar nested, the status dot rolled up from children),
    which needs nothing and is needed by step 18. Then Phases 2 and 3, the palette and what
    applies now, drawn on the command language from step 7 and the operation specs from
    step 6 rather than on a second path of their own.
15. **(agent)** Phase 0 of [`plans/claim-graph.md`](plans/claim-graph.md): generate claim
    nodes from two or three real threads with structure only and no sentence from any model,
    and check them against the node format and validator the operator keeps elsewhere.
    Needs step 2. A gate: if the structure alone is empty of interest, the commitment point
    is the wrong granularity and step 16 does not happen. Then Phases 1 to 3 if it holds:
    thread-local claims, ancestry, the claims view, and promotion one claim at a time.
16. **(agent)** Phases 1 to 3 of
    [`plans/context-queries.md`](plans/context-queries.md): record what today's hand-off
    seed carries, then build a seed from claims under a size budget with the query
    recorded, then run the comparison through the evals harness the operator already has.
    Phase 1 needs nothing; Phases 2 and 3 need step 15. The one number this track turns on:
    does a hand-off seeded with claims beat one seeded with the transcript at equal size?
    Write the result in whichever way it goes.
17. **(agent)** [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md): one OSC 8
    link primitive in `Stratta.TUI.Render`, then the links Stratta generates itself (PR
    URLs, diff file paths); the width-accounting tests in Phase 1 are the part that
    matters. Then [`plans/composer-editing.md`](plans/composer-editing.md): a wrapped,
    cursor-editable composer in the viewer, replacing the append-only single line. The
    first needs nothing; the second follows step 11, because both want the composer's
    arrow keys and the second one in should follow the first one's precedence rule.
18. **(agent, operator decides first)** Phase 2 of the delegated-authority plan
    (narrowing: grants that name tools, thread, folder and expiry, and hand-down that can
    only weaken), then Phases 0 to 2 of
    [`plans/agent-approver.md`](plans/agent-approver.md): referral, the reviewer thread,
    reasons and reversal. Needs steps 4, 9 and 14. Do not start the narrowing unless a
    reviewer is actually wanted — it is the feature that pays for it, and authority built
    without it is platform work. See the question below.
19. **(agent, blocked on operator)** Phase 0 of
    [`plans/remote-access.md`](plans/remote-access.md), the forwarding recipes, which are
    the two untested paths the gui-first plan names in its Design 8. Then Phase 5 of the
    gui-first plan: remote hosts over SSH, which also wants that plan's Design 1,
    everything the app does going through `Stratta.API`. Both need two machines.
20. **(agent)** Test whether `Stratta.ThreadServer.terminate/2` runs when it is needed. It
    saves the timeline and closes the agent's session, but the process does not trap exits,
    and both `Threads.delete_thread/1` and a daemon shutdown stop it through its supervisor.
    By OTP's rule a GenServer that does not trap exits is then killed without `terminate/2`
    being called. This was read from the code, not run. Two tests settle it: delete a thread
    that has a live demo-agent session and assert that the session ends; stop the daemon
    inside the save debounce after an event and assert that the item is on disk. If either
    fails, the likely fix is to trap exits in `init/1` and handle the exit messages that
    follow. Needs nothing and can be done at any time; it is last only so that the numbers
    above do not shift.

Not scheduled: [`plans/thread-environments.md`](plans/thread-environments.md), because
nothing in the graph depends on it. It never blocks anything, so it can run whenever it is
wanted, starting with its Phase 0 spike on how an agent CLI's own login reaches a fresh
environment and its Phase 1, which extracts the behaviour and changes nothing visible.

Every other phase of every plan, each waiting on a finding or a decision that does not
exist yet: Phases 1 to 4 of the code-mode plan, which wait for an orchestrating model;
Phases 2 and 4 of the pane-threads plan, its Phase 3 being superseded by step 4; Phase 4 of
the policy plan, the assessment of letting a Jido runtime own the thread; Phases 3 and 4 of
the telemetry plan, which need their measures defined tightly enough to test; Phases 4 and
5 of the behaviour-shaped-UI plan; Phase 4 of the claim-graph plan and Phases 4 and 5 of
the context-queries plan, which wait on step 16's result; Phases 3 and 4 of the
delegated-authority plan, the external verifier and signed answers; Phase 3 of the
agent-approver plan; Phase 6 of the gui-first plan; and Phases 1 to 3 of the remote-access
plan, which wait on step 19.
