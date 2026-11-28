---
type: handoff
updated: 2026-11-28
---

# Next

> The ordered list of what's next, and nothing else. What is true now is in `state.md`. The first open step is mirrored in direction's `repo-manifest.md`: change this file with `/update-next`, or run it after a hand edit (repo-template R30).

1. **(operator; need)** Send the report from your first runs on your own machine,
   and in the same sitting do Phase 0 of the composed-surfaces plan, which has no code.
   The points that are still unknown here: which agent you ran and whether a real agent
   has been run at all; whether ctrl-c and ctrl-s behave in `stratta attach` on your
   system; and how Rex shows a thread's status while `stratta attach` or
   `stratta watch` is open, including whether the per-thread records from the dashboard
   appear as separate entries. Then the app in a terminal-browser pane
   (`terminal-browser open localhost:4001 --split right`), beside the viewer: whether the thread page streams and whether the diff panel draws.
   Write what you saw into that plan's Findings. On the same machine, run the suite and
   report the result, in `core/` and again in `tui/`: `mix deps.get && mix test`. CI runs
   it on Linux on every push and it passes there; it has not been run on a Mac. Say
   which Elixir and Erlang/OTP the machine has (`elixir --version`), which step 7 and
   the pinned versions wait on.
   Read first, in the tutorial: [Terminals: escape sequences, raw mode and pseudo-terminals](md/docs/tutorial/source/tutorial.md#20-terminals-escape-sequences-raw-mode-and-pseudo-terminals).
2. **(agent, blocked on operator; experiment)** Try PropertyDamage on the daemon and say
   whether to use it. Background:
   [`md/analysis/2026-11-27-property-damage/property-damage.md`](md/analysis/2026-11-27-property-damage/property-damage.md),
   section 8. It needs a session on a machine with the versions Stratta requires and
   access to Hex, the suite from step 1 passing there, and the operator present: the
   library ships a skill, `pd-model-interview`, that interviews him about how one
   subsystem should behave, writes `model_spec.md` as the source of truth and generates
   the model from it. Use it on the smallest subsystem with a rule he fears breaking.
   Through `Stratta.API`, with the demo agent. It answers four things: whether an adapter
   inside the daemon's node works with events that arrive later; whether a failure
   shrinks to something readable; whether the coverage reports a rule that never fired;
   how long 100 sequences take against a real Harness session. Write the answers as a new
   analysis, and say yes or no. "No, use StreamData with the spike's pattern" is a
   possible answer. It also settles step 25. Placed second by the operator.
   Read first, in the tutorial: [A pure core inside a process shell](md/docs/tutorial/source/tutorial.md#11-a-pure-core-inside-a-process-shell); [Events, sequence numbers and what survives a restart](md/docs/tutorial/source/tutorial.md#12-events-sequence-numbers-and-what-survives-a-restart); [Stratta.API: a closed set of named operations](md/docs/tutorial/source/tutorial.md#16-strattaapi-a-closed-set-of-named-operations).
3. **(agent; need)** What is left of Phase 1 of
   [`md/plans/2026-11-28-adopt-propertydamage-method/adopt-propertydamage-method.md`](md/plans/2026-11-28-adopt-propertydamage-method/adopt-propertydamage-method.md),
   then Phase 2. Phase 1 is the gate, and CI runs it on every push
   ([`md/docs/ci.md`](md/docs/ci.md)). Left, each a change to the workflow and so
   followed by its control: a `core/mix.lock`, so that the three apps are tested against
   one version of Harness
   ([the issue](md/issues/2026-11-28-ci-first-run.md), item 2); the tutorial's checks and the layout check as a fourth
   job; `mix credo --strict`, after one run of it has been read; and `.tool-versions`,
   which waits on step 7. Phase 2 is the timeline's spec in
   `openspec/specs/timeline/spec.md`, from the fourteen rules of the spike in
   `md/analysis/2026-11-27-verification-design/spike/`; two of its requirements wait on
   steps 4 and 5. The lock file and credo change `mix.lock` files, which a cloud session
   cannot write because it cannot run Mix. It can do the rest: push, and read the run.
   Read first, in the tutorial: [A pure core inside a process shell](md/docs/tutorial/source/tutorial.md#11-a-pure-core-inside-a-process-shell); [Events, sequence numbers and what survives a restart](md/docs/tutorial/source/tutorial.md#12-events-sequence-numbers-and-what-survives-a-restart); [The gate, and the machine that runs it](md/docs/tutorial/source/tutorial.md#41-the-gate-and-the-machine-that-runs-it).
4. **(operator; need)** Decide what a thread shows for a tool call that never finished.
   [`md/analysis/2026-11-27-open-tool-calls/open-tool-calls.md`](md/analysis/2026-11-27-open-tool-calls/open-tool-calls.md)
   gives the background and three options: leave the item as the agent left it; close it
   when the turn ends and record that Stratta closed it; or store it as it is and work
   out the display. Items 1 to 4 of the fold issue wait on this.
   Read first, in the tutorial: [A pure core inside a process shell](md/docs/tutorial/source/tutorial.md#11-a-pure-core-inside-a-process-shell); [Events, sequence numbers and what survives a restart](md/docs/tutorial/source/tutorial.md#12-events-sequence-numbers-and-what-survives-a-restart).
5. **(operator; need)** Decide whether the code that folds events may ever raise.
   [`md/analysis/2026-11-27-malformed-events/malformed-events.md`](md/analysis/2026-11-27-malformed-events/malformed-events.md)
   gives the background and three options: leave it, so a malformed event ends the
   thread's session; make the fold accept anything and put a notice in the thread; or
   catch the error where events arrive. Item 5 of the fold issue waits on this.
   Read first, in the tutorial: [Links, monitors and letting it crash](md/docs/tutorial/source/tutorial.md#7-links-monitors-and-letting-it-crash); [A pure core inside a process shell](md/docs/tutorial/source/tutorial.md#11-a-pure-core-inside-a-process-shell); [ACP: what an agent speaks in protocol mode](md/docs/tutorial/source/tutorial.md#18-acp-what-an-agent-speaks-in-protocol-mode).
6. **(operator; need)** Decide how a second reader sees each change.
   [`md/analysis/2026-11-28-second-reader/second-reader.md`](md/analysis/2026-11-28-second-reader/second-reader.md)
   says it can be automatic with nobody in the loop, and what is known about which
   model. The choices: keep pushing to `main` and review after the push; pull requests
   where CI must pass and an automated reviewer advises, which the analysis recommends;
   the same with the reviewer required; or either with a second reviewer from another
   maker. Anything but the first is an exception to pushing straight to `main`, and
   needs you to add a secret for the reviewer's model in the repository's settings.
   CI exists now and does not block: a push to `main` lands, and the run reports a
   minute later.
   Read first, in the tutorial: [The gate, and the machine that runs it](md/docs/tutorial/source/tutorial.md#41-the-gate-and-the-machine-that-runs-it).
7. **(operator; experiment)** Decide whether Stratta requires Elixir 1.20, and say which
   Elixir and Erlang/OTP your machine runs.
   [`md/analysis/2026-11-27-elixir-1-20/elixir-1-20.md`](md/analysis/2026-11-27-elixir-1-20/elixir-1-20.md)
   recommends yes, together with something that fails a push on a compiler warning, and
   after one compile on 1.20 has been read. Both now exist: CI treats a warning as an
   error, and runs each app on Elixir 1.20 on every push without failing the run. On
   1.20 every test passes and the compiler reports three things 1.19 does not, each of
   them code that does nothing
   ([the issue](md/issues/2026-11-28-ci-first-run.md), item 3). If yes, an agent fixes
   the three and makes the 1.20 jobs the required ones.
   Read first, in the tutorial: [The gate, and the machine that runs it](md/docs/tutorial/source/tutorial.md#41-the-gate-and-the-machine-that-runs-it).
8. **(agent, blocked on operator; experiment)** Phase 0 of
   [`md/plans/2026-11-25-pane-threads-via-hooks/pane-threads-via-hooks.md`](md/plans/2026-11-25-pane-threads-via-hooks/pane-threads-via-hooks.md): the spike that
   answers whether Claude Code still shows its own permission dialog while a
   `PermissionRequest` hook holds the request, and the six smaller questions listed
   there. It needs a session on a machine with Claude Code 2.1.295 or later, signed in.
   Write the findings into the plan's last section. In the same session, do Phase 4 of
   the slash-commands plan (what real agents advertise) Phase 0 of
   [`md/plans/2026-11-26-choice-requests/choice-requests.md`](md/plans/2026-11-26-choice-requests/choice-requests.md) (what options real agents put
   on a request), and Phase 0b of the composed-surfaces plan: a spike on the two other
   ways to draw a view, QIP components and a PixelGUI program, each asked the same five
   questions and judged against a page. The
   spike's reading and building need nothing and can start at once; only the look at
   pixels in a real pane needs the operator's terminal. Its finding should be in before
   step 14 if possible, because it bears on what views are made of. Second because a pane thread is how an agent's own interface becomes a
   pane, and its answer is go or no-go for step 15. Nothing below waits for it except
   step 15.
   Read first, in the tutorial: [ACP: what an agent speaks in protocol mode](md/docs/tutorial/source/tutorial.md#18-acp-what-an-agent-speaks-in-protocol-mode); [Hooks: the agent's own interface, reporting in](md/docs/tutorial/source/tutorial.md#19-hooks-the-agents-own-interface-reporting-in).
9. **(agent; need)** Phases 0 to 2 of [`md/plans/2026-11-25-decision-records/decision-records.md`](md/plans/2026-11-25-decision-records/decision-records.md):
   the hand-written record from a recorded thread that decides whether the evidence slot is
   derivable, and whether an evidence id points at a timeline item or at an entry in a
   file of events ([`md/plans/2026-11-26-event-log/event-log.md`](md/plans/2026-11-26-event-log/event-log.md), Phases 2 to 4), then
   `Stratta.Decision`, its store, both times and `stratta decisions`, then
   the evidence — the ids of the timeline events between the start of the turn and the
   request. The root of the graph: steps 10, 11, 15, 16, 18 and 20 all read this record, and
   Phase 2 in particular is where step 20's claims get their grounds, so it is not
   optional to that track. Worth having alone, because "why was `2a` approved, and how
   long did it wait?" cannot be answered today.
   Read first, in the tutorial: [A pure core inside a process shell](md/docs/tutorial/source/tutorial.md#11-a-pure-core-inside-a-process-shell); [Events, sequence numbers and what survives a restart](md/docs/tutorial/source/tutorial.md#12-events-sequence-numbers-and-what-survives-a-restart); [A decision as a record](md/docs/tutorial/source/tutorial.md#26-a-decision-as-a-record).
10. **(agent; need)** Phases 1 and 2 of
   [`md/plans/2026-11-25-decision-telemetry/decision-telemetry.md`](md/plans/2026-11-25-decision-telemetry/decision-telemetry.md): threads, turns and tool
   calls as OpenTelemetry spans with the OTLP exporter off by default, then the decision
   span and waiting time split into the agent's part and the operator's. Phase 1 needs
   nothing; Phase 2 needs step 9. Small, and it is what makes step 9 pay immediately. It
   is also the data the first graphical view in step 22 is most likely to draw.
    Read first, in the tutorial: [Traces and measures](md/docs/tutorial/source/tutorial.md#27-traces-and-measures).
11. **(agent; exploration)** Phase 0 then Phase 1 of
   [`md/plans/2026-11-25-policy-as-actions/policy-as-actions.md`](md/plans/2026-11-25-policy-as-actions/policy-as-actions.md): the go/no-go on taking
   `jido` as a dependency, then the rule set, the three shipped rules, and every automatic
   answer naming the rule that fired. Phase 0 needs nothing; Phase 1 needs step 9, so that
   an automatic answer is recorded with its rule. This is the README's first next step and
   it supersedes Phase 3 of the pane-threads plan. Phase 2 (the same rules as Jido actions
   and a skill) only if Phase 0 says yes; Phase 3 ("always allow this", which appends a rule
   and says which one it appended) follows Phase 1 whenever it is wanted. Two facts for
   Phase 0, read from the Jido repository at `14424fe` and not yet from a build: its `main`
   is `3.0.0-beta.3`, a beta that merges four packages into one, so its required
   dependencies include an HTTP client and a language-model client that rules would never
   call; and what the plan calls a skill is a `Jido.Plugin` there (in that version a skill
   is a loader for `SKILL.md` files), so Phase 2's wording changes with it. A third, from
   the same reading: that version also has flows (graphs of calls to actions, declared
   as data, with waits that hold no process), durable runs of flows described as needing
   no AgentServer, agent topology and a blackboard. With Phase 0's build, do the spike in
   Phase 0 of [`md/plans/2026-11-26-graphs/graphs.md`](md/plans/2026-11-26-graphs/graphs.md): one flow whose actions call
   `Stratta.API`, run under `Jido.Durable` with the file adapter. Its finding goes into
   that plan and does not bear on the go/no-go.
    Read first, in the tutorial: [Jido in one section: values, signals and turns](md/docs/tutorial/source/tutorial.md#22-jido-in-one-section-values-signals-and-turns); [Plugins, which the plans call skills](md/docs/tutorial/source/tutorial.md#23-plugins-which-the-plans-call-skills); [Who owns the session: Route A and Route B](md/docs/tutorial/source/tutorial.md#24-who-owns-the-session-route-a-and-route-b); [Flows, waits and a blackboard: the rest of Jido](md/docs/tutorial/source/tutorial.md#25-flows-waits-and-a-blackboard-the-rest-of-jido); [Policy: rules that answer](md/docs/tutorial/source/tutorial.md#28-policy-rules-that-answer); [Two graphs: what a thread leaves behind, and work across threads](md/docs/tutorial/source/tutorial.md#34-two-graphs-what-a-thread-leaves-behind-and-work-across-threads).
12. **(agent; need)** Phase 0 of
   [`md/plans/2026-11-25-delegated-authority/delegated-authority.md`](md/plans/2026-11-25-delegated-authority/delegated-authority.md): reproduce, as a test,
   an agent-run shell command approving another thread's pending request. With it, Phase 3
   of the composed-surfaces plan: the same answer given through the app, which has no
   login, by a process that is not the operator's browser. Needs nothing. Both belong in
   the suite before step 16 claims to have closed them.
    Read first, in the tutorial: [The control socket](md/docs/tutorial/source/tutorial.md#15-the-control-socket); [Authority: from reaching the socket to holding a grant](md/docs/tutorial/source/tutorial.md#29-authority-from-reaching-the-socket-to-holding-a-grant).
13. **(agent; exploration)** Phase 0 of [`md/plans/2026-11-25-code-mode-orchestrator/code-mode-orchestrator.md`](md/plans/2026-11-25-code-mode-orchestrator/code-mode-orchestrator.md):
   describe every `Stratta.API` operation (arguments, result, one line, read-only or not),
   add `stratta ops`, and a test that fails when an operation has no spec. Then Phase 2 of
   the composed-surfaces plan: `md/docs/socket-protocol.md`, a protocol version in `ping`,
   and a client in a second language that lists threads and follows one. Needs nothing.
   The specs are most of the protocol document, which is why the two sit together; step
   22 needs the protocol, and so does anything remote.
    Read first, in the tutorial: [The control socket](md/docs/tutorial/source/tutorial.md#15-the-control-socket); [Stratta.API: a closed set of named operations](md/docs/tutorial/source/tutorial.md#16-strattaapi-a-closed-set-of-named-operations); [One registry, three renderers](md/docs/tutorial/source/tutorial.md#31-one-registry-three-renderers).
14. **(agent; exploration)** Phase 1 of the composed-surfaces plan: the app taken apart. A page layout
   with nothing around it and the first three views cut out of the app as shared
   components (`timeline`, `diff`, `requests`), with the whole-app page rebuilt on them
   and its tests unchanged. `stratta open --view NAME`, `STRATTA_VIEW` and `STRATTA_URL`
   for the opener, `app.url`, and `stratta views`, the list an agent reads to learn what
   it can put in front of the operator. Two example openers, and one example status hook
   that opens a diff view while a thread waits and closes it when the thread resumes.
   Needs nothing; after step 13 so that the new operations arrive with specs. From here
   on, a step that adds something to look at adds it as a view: the decisions list
   (step 9, added here if it has landed), the grants that are live (step 16), the claims
   of a thread (step 20).
    Read first, in the tutorial: [PubSub: topics and subscribers](md/docs/tutorial/source/tutorial.md#13-pubsub-topics-and-subscribers); [Snapshots, and pushing no faster than a client reads](md/docs/tutorial/source/tutorial.md#14-snapshots-and-pushing-no-faster-than-a-client-reads); [Terminals: escape sequences, raw mode and pseudo-terminals](md/docs/tutorial/source/tutorial.md#20-terminals-escape-sequences-raw-mode-and-pseudo-terminals).
15. **(agent; experiment)** Phase 1 of the pane-threads plan: requests only (`stratta run`,
   `stratta hook`, `Stratta.PaneThread`), including the check that stops an agent from
   approving its own requests. Needs step 8's findings. Then Phase 3 of the
   decision-records plan, so that a request raised through a hook produces the same record
   as a headless one and there is only ever one record type; that half needs step 9.
    Read first, in the tutorial: [Hooks: the agent's own interface, reporting in](md/docs/tutorial/source/tutorial.md#19-hooks-the-agents-own-interface-reporting-in); [Behaviours: a contract a module signs](md/docs/tutorial/source/tutorial.md#21-behaviours-a-contract-a-module-signs).
16. **(agent; need)** Phase 1 of the delegated-authority plan: the behaviour, the unforgeable
    local grant, a grant on every answering path, the grant id in the decision record, and
    step 12's two reproductions now refused. Needs steps 9 and 12. After step 15 where
    possible, so that the hook's path is one of the answering paths it covers from the
    start.
    Read first, in the tutorial: [Behaviours: a contract a module signs](md/docs/tutorial/source/tutorial.md#21-behaviours-a-contract-a-module-signs); [Authority: from reaching the socket to holding a grant](md/docs/tutorial/source/tutorial.md#29-authority-from-reaching-the-socket-to-holding-a-grant).
17. **(agent; need)** The terminal client as a place to work. Phases 1 and 2 of
    [`md/plans/2026-11-25-slash-commands/slash-commands.md`](md/plans/2026-11-25-slash-commands/slash-commands.md): keep the list of slash commands
    an agent advertises, add `stratta commands`, and suggest them in the viewer's
    composer. Then [`md/plans/2026-11-25-terminal-hyperlinks/terminal-hyperlinks.md`](md/plans/2026-11-25-terminal-hyperlinks/terminal-hyperlinks.md): one
    OSC 8 link primitive in `Stratta.TUI.Render`, then the links Stratta generates itself
    (PR URLs, diff file paths, and a thread's page in the app through step 14's
    `app.url`); the width-accounting tests in Phase 1 are the part that matters. Then
    [`md/plans/2026-11-25-composer-editing/composer-editing.md`](md/plans/2026-11-25-composer-editing/composer-editing.md): a wrapped, cursor-editable
    composer in the viewer, replacing the append-only single line. The first two need
    nothing; the third follows the first, because both want the composer's arrow keys and
    the second one in should follow the first one's precedence rule.
    Read first, in the tutorial: [ACP: what an agent speaks in protocol mode](md/docs/tutorial/source/tutorial.md#18-acp-what-an-agent-speaks-in-protocol-mode); [Terminals: escape sequences, raw mode and pseudo-terminals](md/docs/tutorial/source/tutorial.md#20-terminals-escape-sequences-raw-mode-and-pseudo-terminals).
18. **(agent; exploration)** Phase 1 of the choice-requests plan: a request carries a kind and a list
    of options, an answer names one, and the decision record carries them. Needs step 9,
    and reads step 8's findings on what real agents send if they exist by then. Phase 2
    (references: pointing at a hunk, a file or a region from a view) needs step 14 and
    follows whenever it is wanted.
    Read first, in the tutorial: [Events, sequence numbers and what survives a restart](md/docs/tutorial/source/tutorial.md#12-events-sequence-numbers-and-what-survives-a-restart); [A decision as a record](md/docs/tutorial/source/tutorial.md#26-a-decision-as-a-record).
19. **(agent; need)** Phase 1 of [`md/plans/2026-11-25-behaviour-shaped-ui/behaviour-shaped-ui.md`](md/plans/2026-11-25-behaviour-shaped-ui/behaviour-shaped-ui.md):
    a parent thread id on the thread record, threads nested in the dashboard, and the
    status rolled up from children. Needs nothing. The
    whole-app page's sidebar gets the same nesting from the shared component. The parent
    link is also the first line in a graph of work across threads
    ([`md/plans/2026-11-26-graphs/graphs.md`](md/plans/2026-11-26-graphs/graphs.md), Design 4). Whether it should come sooner than
    its number is the operator's to decide.
    Read first, in the tutorial: [One registry, three renderers](md/docs/tutorial/source/tutorial.md#31-one-registry-three-renderers); [Two graphs: what a thread leaves behind, and work across threads](md/docs/tutorial/source/tutorial.md#34-two-graphs-what-a-thread-leaves-behind-and-work-across-threads).
20. **(agent; experiment)** Phase 0 of [`md/plans/2026-11-25-claim-graph/claim-graph.md`](md/plans/2026-11-25-claim-graph/claim-graph.md): generate claim
    nodes from two or three real threads with structure only and no sentence from any model,
    and check them against artifact-dag's node format and its validator.
    Needs step 9. If the structure alone turns out to be of little interest, that is worth
    knowing before going on, and the operator decides what follows. Then Phases 1 to 3:
    thread-local claims, ancestry, the claims view, and promotion one claim at a time.
    Read first, in the tutorial: [A decision as a record](md/docs/tutorial/source/tutorial.md#26-a-decision-as-a-record); [Claims, and context as a recorded query](md/docs/tutorial/source/tutorial.md#33-claims-and-context-as-a-recorded-query).
21. **(agent; experiment)** Phases 1 to 3 of
    [`md/plans/2026-11-25-context-queries/context-queries.md`](md/plans/2026-11-25-context-queries/context-queries.md): record what today's hand-off
    seed carries, then build a seed from claims under a size budget with the query
    recorded, then run the comparison through the evals harness in artifact-dag.
    Phase 1 needs nothing; Phases 2 and 3 need step 20. The question it asks: does a hand-off seeded with
    claims do better than one seeded with the transcript at equal size? Write up what is
    found, whichever way it goes. Beside it, as an experiment and
    not a feature, [`md/plans/2026-11-26-per-request-context/per-request-context.md`](md/plans/2026-11-26-per-request-context/per-request-context.md): a
    fresh run of the agent for each request, started from text Stratta assembles and
    records. Its Phase 1 (the mode and the assembler, against the demo agent) needs
    nothing; Phase 0 belongs to step 8's session on a machine with the agents installed;
    Phase 2 tries it against a session on real work; Phase 3 shares this step's
    claims arm. What follows from it, including whether Stratta should ever own an
    agent's loop, is the operator's to decide from what is found.
    Read first, in the tutorial: [Claims, and context as a recorded query](md/docs/tutorial/source/tutorial.md#33-claims-and-context-as-a-recorded-query).
22. **(agent; exploration)** Phase 4 of the composed-surfaces plan: the first new view, `timing`,
    waiting time per request split into the agent's part and the operator's, as a page.
    Needs steps 10 and 14. Note every change it needed outside its own module. Then Phase 3 of the choice-requests plan (a view that draws a
    request's options and sends back the one picked), which needs step 18.
    Read first, in the tutorial: [PubSub: topics and subscribers](md/docs/tutorial/source/tutorial.md#13-pubsub-topics-and-subscribers); [Traces and measures](md/docs/tutorial/source/tutorial.md#27-traces-and-measures).
23. **(agent; exploration)** Phase 2 of the delegated-authority plan, for views: grants that name
    what they may answer (tools, thread, folder, expiry), hand-down that can only weaken,
    and each view holding a grant cut to its job, as the composed-surfaces plan's Design
    7 says. Most views can look; `requests` can answer; a view opened by an agent can
    only look. `stratta grants` lists views among the holders. Needs steps 14 and 16 and
    can start as soon as both have landed. Whether it should come sooner than its
    number is the operator's to decide.
    Read first, in the tutorial: [Authority: from reaching the socket to holding a grant](md/docs/tutorial/source/tutorial.md#29-authority-from-reaching-the-socket-to-holding-a-grant).
24. **(agent, blocked on operator; exploration)** Phase 0 of
    [`md/plans/2026-11-25-remote-access/remote-access.md`](md/plans/2026-11-25-remote-access/remote-access.md), the terminal half: the client
    against a socket forwarded over SSH, and a view page reached through a forwarded
    port, which are the two paths the app-first plan's Design 8 names as never tried.
    Needs two machines.
    Read first, in the tutorial: [Stratta.API: a closed set of named operations](md/docs/tutorial/source/tutorial.md#16-strattaapi-a-closed-set-of-named-operations); [Files, shells, hosts and environments](md/docs/tutorial/source/tutorial.md#35-files-shells-hosts-and-environments).
25. **(agent; need)** Test whether `Stratta.ThreadServer.terminate/2` runs when it is needed. It
    saves the timeline and closes the agent's session, but the process does not trap exits,
    and both `Threads.delete_thread/1` and a daemon shutdown stop it through its supervisor.
    By OTP's rule a GenServer that does not trap exits is then killed without `terminate/2`
    being called. This was read from the code, not run. Two tests settle it: delete a thread
    that has a live demo-agent session and assert that the session ends; stop the daemon
    inside the save debounce after an event and assert that the item is on disk. If either
    fails, the likely fix is to trap exits in `init/1` and handle the exit messages that
    follow. Needs nothing and can be done at any time; it is last only because nothing
    waits on it. Phase 3 of the event-log plan would cover the second case by another
    route, events written as they arrive, and the tests are worth having either way. The
    finding is filed in
    [`md/issues/2026-11-27-thread-server-terminate.md`](md/issues/2026-11-27-thread-server-terminate.md).
    Read first, in the tutorial: [Links, monitors and letting it crash](md/docs/tutorial/source/tutorial.md#7-links-monitors-and-letting-it-crash).
26. **(operator; experiment)** Decide whether
    [`md/plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md`](md/plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md) enters this list,
    and where. It tests your working assumption that agents are adversarial, and
    [the analysis](md/analysis/2026-11-26-habitat-and-stratta/habitat-and-stratta.md) is its background. The options: leave it
    out; add only its Phase 0, a scripted agent that misbehaves on purpose and tests that
    record which boundaries hold, with no fixes, which needs nothing and shares step 12's
    two reproductions; or add it together with Phase 0 of the thread-environments plan,
    because the analysis argues that most boundaries need a thread to run somewhere the
    daemon does not. It is numbered last so that no other step's number changes. Nothing
    waits on it.
    Read first, in the tutorial: [Authority: from reaching the socket to holding a grant](md/docs/tutorial/source/tutorial.md#29-authority-from-reaching-the-socket-to-holding-a-grant).
27. **(operator; need)** Decide whether the design commitments become a governing
    document. They are in
    [`md/docs/design-commitments.md`](md/docs/design-commitments.md), unchanged.
    repo-template puts a rule the repo lives by in `md/governance/`, which holds only
    five named files. The choices: leave them in `md/docs/`; rewrite them as
    `md/governance/POLICY.md`, numbered P1 to P4 with what checks each, and repoint the
    plans that cite them; or split them, since commitments 1 and 2 read as design and 3
    and 4 as rules. Numbered last so that no other step's number changes. Nothing waits
    on it.
28. **(agent, blocked on operator; need)** Run the tutorial's labs and its restart check on
    the versions Stratta requires: `sh md/docs/tutorial/scripts/run_labs.sh` and
    `sh md/docs/tutorial/scripts/check_timeline_ids.sh`, and commit the new transcripts.
    Both have only run on Elixir 1.14.0 with Erlang/OTP 25. Watch for new compiler
    warnings in the exercise files, and run `solutions/02_supervision.exs` a few dozen
    times: one early run did not report a clean pass and its output was lost, and 200
    later runs never repeated it. Numbered after the others so that no step's number
    changes.
29. **(agent; need)** The tutorial's open items, most useful first. Each says what was not
    done.
    - Part 8 describes the gate and CI and nothing else of the method Stratta is now
      built by. It wants a section on what a spec is when the timeline's spec exists, one
      on what a counterexample looks like when generated tests have produced one, and one
      on the second reader when that is decided. Parts 1 to 7 do not describe the plan to
      adopt the method, the adversarial-boundaries plan, or steps 2 to 7; section 36
      names them.
    - No terminal output from Stratta appears in it. Section 3's walk through a
      permission request would be stronger with a recorded demo-agent thread beside it:
      the socket frames of `stratta approve 2a`, and the thread's file before and after.
      Needs a machine that runs Stratta.
    - The method table in section 18 rests on a retrieval tool's answer about one page
      of the Agent Client Protocol and on search excerpts. Read the protocol's overview,
      prompt-turn and tool-call pages for version 1 directly.
    - The hooks reference was read to the first 100,000 of about 283,000 characters.
      The fields of a permission request and the name of the "do not ask again" key were
      not reached. Confirm them when step 8's spike runs.
    - Sections 22 to 25 describe Jido at `14424fe`, a beta. Re-check them when step 11
      builds against Jido, and put the findings of that step's durable-flow spike into
      sections 25 and 34.
    - There is no lab for sections 22 to 25. A useful one: the three shipped rules as
      actions in one agent, with Lab 7's policy tests passing against it unchanged.
    - The seven diagrams scroll sideways on a narrow screen, and section 34 has no
      picture of its two graphs.
