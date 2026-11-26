---
type: handoff
updated: 2026-11-26
---

# Next

> This file's first open step is mirrored in direction's `repo-manifest.md`. Change it by asking an agent to run `update-next`. If you edit it by hand, run `update-next` afterwards.

## Next, in order

The order is the dependency graph: each step comes after everything it needs and nowhere
later. Where two steps do not constrain each other, the operator's direction decides. That
direction changed on 2026-11-26. The operator's host terminal, Rex first, is the
environment, and Stratta is a guest in it ([`plans/composed-surfaces.md`](plans/composed-surfaces.md)):
the agent's own interface in a pane, and views that the operator or an agent opens beside
it. The app is not dropped. It is taken apart into views, each a page that draws one
thing, shown in a pane by terminal-browser, and bound to the daemon's
state as the app is today. What waits is the app as the place the operator lives: its
command bar, its file editor, its shell and its list of hosts, listed after the steps as
a follow-up. Three things moved because of it: the pane-threads spike is second; an
editor and a shell are panes of the host and are no longer built into a web page; and the
local grant is wanted for its own sake, because views that can answer need one.

Each step carries its kind, as [design commitments](docs/design-commitments.md) defines
them: a **need** is something observed in use or a fact in the code; an **experiment** is
a question with a gate; an **exploration** is built because the operator wants to try
the idea. Most of this list is experiment and exploration, and that is deliberate now
that it is said. What it must not do is run ahead of use again. **Steps 1 to 4 are the
gate**: a day of real work, then the record of decisions and how long each waited. When
they are done, everything after step 4 is ranked again against what they showed, and a
step whose reason did not survive is unscheduled.

1. **(operator; need)** Send the report from your first runs on your own machine (2026-11-25),
   and in the same sitting do Phase 0 of the composed-surfaces plan, which has no code.
   The points that are still unknown here: which agent you ran and whether a real agent
   has been run at all; whether ctrl-c and ctrl-s behave in `stratta attach` on your
   system; and how Rex shows a thread's status while `stratta attach` or
   `stratta watch` is open, including whether the per-thread records from the dashboard
   appear as separate entries. Then the app in a terminal-browser pane
   (`terminal-browser open localhost:4001 --split right`), beside the viewer: whether the thread page streams and whether the diff panel draws.
   Write what you saw into that plan's Findings. Hex is no longer one of the unknowns; see
   the lock files in State.
2. **(agent, blocked on operator; experiment)** Phase 0 of
   [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md): the spike that
   answers whether Claude Code still shows its own permission dialog while a
   `PermissionRequest` hook holds the request, and the six smaller questions listed
   there. It needs a session on a machine with Claude Code 2.1.295 or later, signed in.
   Write the findings into the plan's last section. In the same session, do Phase 4 of
   the slash-commands plan (what real agents advertise) Phase 0 of
   [`plans/choice-requests.md`](plans/choice-requests.md) (what options real agents put
   on a request), and Phase 0b of the composed-surfaces plan: a spike on the two other
   ways to draw a view, QIP components and a PixelGUI program, each asked the same five
   questions and judged against a page. The
   spike's reading and building need nothing and can start at once; only the look at
   pixels in a real pane needs the operator's terminal. Its finding should be in before
   step 8 if possible, because it bears on what views are made of. Second because a pane thread is how an agent's own interface becomes a
   pane, and its answer is go or no-go for step 9. Nothing below waits for it except
   step 9.
3. **(agent; need)** Phases 0 to 2 of [`plans/decision-records.md`](plans/decision-records.md):
   the hand-written record from a recorded thread that decides whether the evidence slot is
   derivable, then `Stratta.Decision`, its store, both times and `stratta decisions`, then
   the evidence — the ids of the timeline events between the start of the turn and the
   request. The root of the graph: steps 4, 5, 9, 10, 12 and 14 all read this record, and
   Phase 2 in particular is where step 14's claims get their grounds, so it is not
   optional to that track. Worth having alone, because "why was `2a` approved, and how
   long did it wait?" cannot be answered today.
4. **(agent; need)** Phases 1 and 2 of
   [`plans/decision-telemetry.md`](plans/decision-telemetry.md): threads, turns and tool
   calls as OpenTelemetry spans with the OTLP exporter off by default, then the decision
   span and waiting time split into the agent's part and the operator's. Phase 1 needs
   nothing; Phase 2 needs step 3. Small, and it is what makes step 3 pay immediately. It
   is also the data the first graphical view in step 16 is most likely to draw.
5. **(agent; exploration)** Phase 0 then Phase 1 of
   [`plans/policy-as-actions.md`](plans/policy-as-actions.md): the go/no-go on taking
   `jido` as a dependency, then the rule set, the three shipped rules, and every automatic
   answer naming the rule that fired. Phase 0 needs nothing; Phase 1 needs step 3, so that
   an automatic answer is recorded with its rule. This is the README's first next step and
   it supersedes Phase 3 of the pane-threads plan. Phase 2 (the same rules as Jido actions
   and a skill) only if Phase 0 says yes; Phase 3 ("always allow this", which appends a rule
   and says which one it appended) follows Phase 1 whenever it is wanted. Two facts for
   Phase 0, read from the Jido repository at `14424fe` and not yet from a build: its `main`
   is `3.0.0-beta.3`, a beta that merges four packages into one, so its required
   dependencies include an HTTP client and a language-model client that rules would never
   call; and what the plan calls a skill is a `Jido.Plugin` there (in that version a skill
   is a loader for `SKILL.md` files), so Phase 2's wording changes with it.
6. **(agent; need)** Phase 0 of
   [`plans/delegated-authority.md`](plans/delegated-authority.md): reproduce, as a test,
   an agent-run shell command approving another thread's pending request. With it, Phase 3
   of the composed-surfaces plan: the same answer given through the app, which has no
   login, by a process that is not the operator's browser. Needs nothing. Both belong in
   the suite before step 10 claims to have closed them.
7. **(agent; exploration)** Phase 0 of [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md):
   describe every `Stratta.API` operation (arguments, result, one line, read-only or not),
   add `stratta ops`, and a test that fails when an operation has no spec. Then Phase 2 of
   the composed-surfaces plan: `docs/socket-protocol.md`, a protocol version in `ping`,
   and a client in a second language that lists threads and follows one. Needs nothing.
   The specs are most of the protocol document, which is why the two sit together; step
   16 needs the protocol, and so does anything remote.
8. **(agent; exploration)** Phase 1 of the composed-surfaces plan: the app taken apart. A page layout
   with nothing around it and the first three views cut out of the app as shared
   components (`timeline`, `diff`, `requests`), with the whole-app page rebuilt on them
   and its tests unchanged. `stratta open --view NAME`, `STRATTA_VIEW` and `STRATTA_URL`
   for the opener, `app.url`, and `stratta views`, the list an agent reads to learn what
   it can put in front of the operator. Two example openers, and one example status hook
   that opens a diff view while a thread waits and closes it when the thread resumes.
   Needs nothing; after step 7 so that the new operations arrive with specs. From here
   on, a step that adds something to look at adds it as a view: the decisions list
   (step 3, added here if it has landed), the grants that are live (step 10), the claims
   of a thread (step 14).
9. **(agent; experiment)** Phase 1 of the pane-threads plan: requests only (`stratta run`,
   `stratta hook`, `Stratta.PaneThread`), including the check that stops an agent from
   approving its own requests. Needs step 2's findings. Then Phase 3 of the
   decision-records plan, so that a request raised through a hook produces the same record
   as a headless one and there is only ever one record type; that half needs step 3.
10. **(agent; need)** Phase 1 of the delegated-authority plan: the behaviour, the unforgeable
    local grant, a grant on every answering path, the grant id in the decision record, and
    step 6's two reproductions now refused. Needs steps 3 and 6. After step 9 where
    possible, so that the hook's path is one of the answering paths it covers from the
    start.
11. **(agent; need)** The terminal client as a place to work. Phases 1 and 2 of
    [`plans/slash-commands.md`](plans/slash-commands.md): keep the list of slash commands
    an agent advertises, add `stratta commands`, and suggest them in the viewer's
    composer. Then [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md): one
    OSC 8 link primitive in `Stratta.TUI.Render`, then the links Stratta generates itself
    (PR URLs, diff file paths, and a thread's page in the app through step 8's
    `app.url`); the width-accounting tests in Phase 1 are the part that matters. Then
    [`plans/composer-editing.md`](plans/composer-editing.md): a wrapped, cursor-editable
    composer in the viewer, replacing the append-only single line. The first two need
    nothing; the third follows the first, because both want the composer's arrow keys and
    the second one in should follow the first one's precedence rule.
12. **(agent; exploration)** Phase 1 of the choice-requests plan: a request carries a kind and a list
    of options, an answer names one, and the decision record carries them. Needs step 3,
    and reads step 2's findings on what real agents send if they exist by then. Phase 2
    (references: pointing at a hunk, a file or a region from a view) needs step 8 and
    follows whenever it is wanted.
13. **(agent; need)** Phase 1 of [`plans/behaviour-shaped-ui.md`](plans/behaviour-shaped-ui.md):
    a parent thread id on the thread record, threads nested in the dashboard, and the
    status rolled up from children. Needs nothing. The
    whole-app page's sidebar gets the same nesting from the shared component.
14. **(agent; experiment)** Phase 0 of [`plans/claim-graph.md`](plans/claim-graph.md): generate claim
    nodes from two or three real threads with structure only and no sentence from any model,
    and check them against artifact-dag's node format and its validator.
    Needs step 3. A gate: if the structure alone is empty of interest, the commitment point
    is the wrong granularity and step 15 does not happen. Then Phases 1 to 3 if it holds:
    thread-local claims, ancestry, the claims view, and promotion one claim at a time.
15. **(agent; experiment)** Phases 1 to 3 of
    [`plans/context-queries.md`](plans/context-queries.md): record what today's hand-off
    seed carries, then build a seed from claims under a size budget with the query
    recorded, then run the comparison through the evals harness in artifact-dag.
    Phase 1 needs nothing; Phases 2 and 3 need step 14. The one number this track turns on:
    does a hand-off seeded with claims beat one seeded with the transcript at equal size?
    Write the result in whichever way it goes. Beside it, as an experiment and
    not a feature, [`plans/per-request-context.md`](plans/per-request-context.md): a
    fresh run of the agent for each request, started from text Stratta assembles and
    records. Its Phase 1 (the mode and the assembler, against the demo agent) needs
    nothing; Phase 0 belongs to step 2's session on a machine with the agents installed;
    Phase 2 measures it against a session and is a gate; Phase 3 shares this step's
    claims arm. It ends in a written answer on whether Stratta should ever own an
    agent's loop.
16. **(agent; exploration)** Phase 4 of the composed-surfaces plan: the first new view, `timing`,
    waiting time per request split into the agent's part and the operator's, as a page.
    Needs steps 4 and 8. It is the test of the direction: list every change it needed
    outside its own module. Then Phase 3 of the choice-requests plan (a view that draws a
    request's options and sends back the one picked), which needs step 12.
17. **(agent; exploration)** Phase 2 of the delegated-authority plan, for views: grants that name
    what they may answer (tools, thread, folder, expiry), hand-down that can only weaken,
    and each view holding a grant cut to its job, as the composed-surfaces plan's Design
    7 says. Most views can look; `requests` can answer; a view opened by an agent can
    only look. `stratta grants` lists views among the holders. Needs steps 8 and 10 and
    can start as soon as both have landed.
18. **(agent, blocked on operator; exploration)** Phase 0 of
    [`plans/remote-access.md`](plans/remote-access.md), the terminal half: the client
    against a socket forwarded over SSH, and a view page reached through a forwarded
    port, which are the two paths the app-first plan's Design 8 names as never tried.
    Needs two machines.
19. **(agent; need)** Test whether `Stratta.ThreadServer.terminate/2` runs when it is needed. It
    saves the timeline and closes the agent's session, but the process does not trap exits,
    and both `Threads.delete_thread/1` and a daemon shutdown stop it through its supervisor.
    By OTP's rule a GenServer that does not trap exits is then killed without `terminate/2`
    being called. This was read from the code, not run. Two tests settle it: delete a thread
    that has a live demo-agent session and assert that the session ends; stop the daemon
    inside the save debounce after an event and assert that the item is on disk. If either
    fails, the likely fix is to trap exits in `init/1` and handle the exit messages that
    follow. Needs nothing and can be done at any time; it is last only because nothing
    waits on it.

Not scheduled, by the operator's decision on 2026-11-26: the reviewer agent, all of
[`plans/agent-approver.md`](plans/agent-approver.md). Requests from coding agents have
been appropriate and informative in attended use, and nothing in the repository records
a moment where answering them was a burden. It returns if unattended work makes it one:
many threads at once, or a daemon working while the operator is away. It would need
steps 5, 13 and 17.

Follow-up, not scheduled: the app as an environment. [`plans/gui-first.md`](plans/gui-first.md)
Phases 1 to 6 (notifications and following, the command language and the command bar, the
files panel and the Markdown editor, the login and the shell in a web page, remote hosts,
scripts), Phase 3 of the slash-commands plan (suggestions in the app's composer), and
Phases 2 and 3 of the behaviour-shaped-UI plan (the palette, which that plan builds on
the app-first plan's command language). They return once the host-terminal direction has
been used, and the first reason to return is to test that direction against a front end
that hosts everything itself. Three parts of the app-first plan are not waiting: its
Design 1, everything the app does going through `Stratta.API`, is what step 7's protocol
document assumes of every client; its protocol version is built in step 7; and its login
is the grant in step 10. Also unscheduled, until a reason is met in use: Phases 5 and 6
of the composed-surfaces plan, a view that is not a page and the spike on a guest inside
the viewer.

Not scheduled: [`plans/thread-environments.md`](plans/thread-environments.md), because
nothing in the graph depends on it. It never blocks anything, so it can run whenever it is
wanted, starting with its Phase 0 spike on how an agent CLI's own login reaches a fresh
environment and its Phase 1, which extracts the behaviour and changes nothing visible.

Every other phase of every plan, each waiting on a finding or a decision that does not
exist yet: Phases 1 to 4 of the code-mode plan, which wait for an orchestrating model;
Phases 2 and 4 of the pane-threads plan, its Phase 3 being superseded by step 5; Phase 4 of
the policy plan, the assessment of letting a Jido runtime own the thread; Phases 3 and 4 of
the telemetry plan, which need their measures defined tightly enough to test; Phases 4 and
5 of the behaviour-shaped-UI plan; Phase 4 of the claim-graph plan and Phases 4 and 5 of
the context-queries plan, which wait on step 15's result; Phases 3 and 4 of the
delegated-authority plan, the external verifier and signed answers; Phase 4 of the choice-requests plan, the declared space, which waits
on step 16; and Phases 1 to 3 of the remote-access plan, which wait on step 18.

## Questions for the operator

- **When does the terminal direction count as used?** The app as an environment returns
  "once the host-terminal direction has been used". A marker would help: for example,
  steps 1 to 10 done and a week of work in it.
