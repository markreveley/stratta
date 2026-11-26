---
type: plan
status: proposed
created: 2026-11-26
---

# Views as separate programs: Stratta as a guest in the host terminal

## Summary

Stratta has two front ends, and each new thing to look at is added to one or both by hand.
This plan changes what the environment is. The operator's host terminal holds the layout.
Stratta supplies views: small things to look at, each started by a shell command, each
bound to the daemon's state, each placed in a pane by the host. The operator opens them,
and so can an agent.

The app does not go away. It is taken apart. Today it is one page that hosts everything:
sidebar, timeline, composer, diff, ship. Here each of those becomes a page of its own that
draws one thing and nothing around it, shown by a browser that draws in a terminal pane.
The pages stay bound to the daemon the way the app is now, so they update without a
reload. The whole-app page stays too, built from the same parts, and becomes the test of
whether the parts are sufficient. What is set aside is the app as the place the operator
lives: its command bar, its file editor, its shell, its list of hosts.

The idea is not new to this repository. The opener (`STRATTA_OPENER`), the status hook
(`STRATTA_STATUS_HOOK`), the status reports and `stratta diff --watch` already treat
Stratta as one program among several in a layout it does not own. This plan finishes that
thought: views get names and addresses, a list says which are on offer, the socket
protocol becomes a documented interface, and a view that should not be a web page has a
place to be built.

The test of whether it is worth doing: **a new view should cost one module or one program,
and no change to `core/` beyond an operation it reads.** If the first new one needs more,
the daemon is not yet the interface this plan assumes, and that is the finding to write
down.

Since 2026-11-26 this is the direction Stratta is built in first. The order of work is in
`next.md`.

Nothing here names a terminal, a browser or a toolkit, per the decision this repository
keeps. The operator's analysis of specific ones is kept elsewhere.

## What exists today

Checked in the code on 2026-11-26, at `412ac68`:

- **The opener.** `stratta open N` runs `$STRATTA_OPENER` with `STRATTA_THREAD`,
  `STRATTA_TITLE`, `STRATTA_CWD` and `STRATTA_BIN`. It hands over a thread, not a view: the
  opener decides alone which views to start.
- **Status.** `Stratta.TUI.Status` writes OSC 7501 and OSC 9;4 reports and runs
  `$STRATTA_STATUS_HOOK` on every change. The dashboard writes one child record per
  thread, `thread/<id>`, and clears the records of threads that go away.
- **The socket.** Length-prefixed JSON frames, `Stratta.API` operations, and `subscribe`
  for one thread, all threads or the current thread. The protocol is described in
  `Stratta.Socket`'s moduledoc and nowhere else. `ping` returns the daemon's version and
  no protocol version.
- **The app is one page.** The router has `/`, `/t/:thread_id` and `/providers`, and one
  module, `StrattaWeb.AppLive`, draws the sidebar, the timeline, the composer and the
  panels together. The diff and ship panels are state inside the thread page, so there is
  no address that shows a diff alone.
- **The daemon knows nothing about panes**, windows or what is on screen. Neither front
  end reports it.
- **Every client is Elixir.** Nothing in another language has spoken the socket.

## Design

### 1. A view is a name, what it takes, and a way to start it

- A view has a name, takes a thread or nothing, and says whether it can answer a request
  or only show. The first ones are what exists: `attach`, `diff`, `dashboard` in the
  terminal client, and the app's parts as pages (Design 2).
- `stratta open --view NAME [N]` passes `STRATTA_VIEW` to the opener, and `STRATTA_URL`
  when the view is a page. With no `--view`, behaviour is as today.
- `stratta views` lists them, and `views.list` is the operation behind it: name, what it
  takes, one line of description, whether it answers. This is how an agent finds out what
  it can put in front of the operator.
- The [app-first plan](gui-first.md)'s command language separates operations from "view
  commands that only a front end can carry out" (`diff`, `files`, `shell`, `open 3`).
  Those are views in this plan's sense, and the opener is where they are carried out.

### 2. The app becomes a kit of views

- Each view is a page of its own at its own address: one LiveView, one subject, no
  sidebar and nothing around it. For example `/v/timeline/<thread>`, `/v/diff/<thread>`,
  `/v/requests`, and later `/v/decisions`, `/v/timing`, `/v/grants`, `/v/claims/<thread>`.
- A view page is bound to the daemon's state by subscription, as the app is today. It
  redraws what changed and never reloads.
- The parts are shared. `AppLive` keeps working and is rebuilt from the same components
  the view pages use. If the whole-app page cannot be made from the views, a view is
  missing or wrong, and that is how the app tests this direction.
- A new operation, `app.url`, returns the address of a view for a thread, or says that no
  app is running in this daemon. The terminal client does not guess a port.
- From here on, a plan that adds something to look at adds it as a view: the decisions
  list, the timing chart, the grants that are live, the claims of a thread.

### 3. An agent can open a view; it cannot answer through one

- An agent opens a view the way the operator does: `stratta open --view timing`. The
  opener places it. This is the kit on offer to the agent: status, progress, timing,
  what is waiting, who holds what authority.
- Opening is showing. A view opened by an agent is the operator's to act in, not the
  agent's. The agent's own requests are refused an answer from it by the same check that
  stops any agent answering itself.
- A view that can answer does so under a grant, and the grant belongs to the view, not
  to whatever opened it (Design 7).

### 4. The daemon still does not know the layout

- No operation reports panes, and none is added. The host terminal knows what is open and
  where. The opener and the status hook are where its knowledge and Stratta's meet, and
  both belong to the operator.
- Rules about what should be visible when ("show the diff while a thread waits on a
  request, close it when the thread resumes") are a status hook. This plan ships one as
  an example and adds nothing to make it possible, because nothing is missing.
- A consequence to state plainly: Stratta cannot close a view it opened. The opener's
  script can, if the host lets it address a pane by a name the script chose.

### 5. The socket is a public interface

- A document, `docs/socket-protocol.md`: framing, request and reply, pushes, coalescing,
  errors. Written from the code, with the moduledoc pointing at it.
- A protocol version in `ping`, as the app-first plan's Design 8 already requires for
  remote hosts. One number, shared.
- A client in a second language, small enough to read in a sitting, kept in the
  repository as the proof that the document is sufficient.

### 6. A view that is not a page

A page costs a browser process for each pane and needs the app running. Two cases want
something else: a view that must work over a plain SSH connection with nothing forwarded,
and a view light enough to leave open all day.

- Such a view is a program of its own, a client of the socket, drawn with a pixel toolkit
  for terminals or as text. It lives in a fourth folder, `views/`, one folder per view,
  with its own build, and depends on the protocol document and on nothing in `core/`,
  `gui/` or `tui/`.
- A toolchain the rest of the repository does not use stays inside that view's folder.
  `tui/` stays one escript in pure Elixir.
- It is listed by `views.list` like any other and opened the same way.

### 7. A view holds the authority it needs and no more

[Authority for an answer](delegated-authority.md) Phase 0 reproduces an agent approving
another thread's request through a shell command. The app is the same hole by another
door. It has no login, so any process running as the operator can connect to it and
answer a request; no browser is needed. A browser that an agent can drive makes it worse
in one way that outlasts a login: once a page's session holds a grant, an agent driving
the browser that holds that session answers with that grant.

- That plan's Phase 0 gains a second reproduction: a process that is not the operator's
  browser answering a request through the app.
- Its Phase 1 gives every answering path a grant. For a view page, the grant is handed to
  the page when it is opened, in a way the opener's caller cannot read back.
- With that plan's narrowing, each view's grant is cut to its job. `timing` and `diff`
  can look and cannot answer. `requests` can answer, and when opened for one thread, only
  that thread's requests. A view opened by an agent gets a grant that can look.
- `stratta grants` then lists views among the holders, so the operator can see which
  pane can do what.

## Phases

### Phase 0: look, with no code (operator; step 1 of `next.md`)

On the operator's own machine, with the demo agent:

- the dashboard and the viewer in a host terminal that reads OSC 7501: what the tab, the
  list of programs and any activity view show for `working`, `blocked` and `done`, and
  whether the per-thread records appear as separate entries;
- the app in a browser that draws in a terminal pane, beside the viewer: whether the
  thread page streams, whether the diff panel draws, whether Approve works;
- the same browser reaching the app on a second machine through an SSH connection, if a
  second machine is at hand;
- which revision of the status protocol the host reads, against what
  `Stratta.TUI.Status.osc7501/2` writes.

Write what was seen into Findings. The second point decides whether Design 2 stands: if a
page of the app does not behave in such a browser, views are built as Design 6 says and
this plan is rewritten.

### Phase 1: named views, the list, and the first pages (medium; step 8 of `next.md`)

`--view`, `STRATTA_VIEW`, `STRATTA_URL`, `app.url`, `views.list` and `stratta views`. The
page layout with nothing around it, and three views cut out of `AppLive` as shared
components: `timeline`, `diff` and `requests`. `AppLive` rebuilt on them, with its tests
unchanged. Two example openers in `tui/README.md` written against a host's command-line
interface in general terms, and one example status hook that opens a diff view while a
thread waits and closes it when the thread resumes. Tests: the opener's environment for
each view; each view page against the demo agent; the list matching the routes.

### Phase 2: the protocol document and a second client (small; step 7 of `next.md`)

`docs/socket-protocol.md`, the protocol version in `ping`, and a client in another
language that lists threads and follows one. A test in `core/` runs it against a real
daemon when its runtime is present and is skipped when it is not.

### Phase 3: the second reproduction (small; step 6 of `next.md`)

A process that is not the operator's browser answering a request through the app, as a
test in the suite. Belongs with the authority plan's Phase 0.

### Phase 4: the first new view (small to medium; step 16 of `next.md`; needs Phase 1 and step 4)

`timing`: waiting time per request, split into the agent's part and the operator's, as a
page. Measured against the summary's test: list every change it needed outside its own
module.

### Phase 5: a view that is not a page (medium; needs Phase 2; when a reason appears)

One view in `views/`, with its build, its README and a line in the root README's layout
table. The reason is one of Design 6's two cases, met in use, not anticipated.

### Phase 6: a guest inside the viewer (a spike; needs Phase 5)

Whether the viewer can give part of its screen to a graphical guest, speaking the guest
toolkit's embedding protocol from Elixir, with no native code in `tui/`. A yes or no with
the reason, not a feature.

## Not in scope

- The app as the operator's environment: a command bar, a file editor, a shell in a web
  page, a list of hosts. Those are the app-first plan's, and wait.
- The daemon tracking, opening or closing panes.
- Naming or detecting a terminal.
- Replacing the terminal client.

## Open questions

- How does a page receive its grant without the address carrying it? An address is
  visible to whatever opened the view. A one-time code exchanged on first load is the
  usual answer; the authority plan's Phase 1 has to settle it.
- Should `views/` live in this repository at all, or should such a view be its own
  repository that depends on the protocol document?
- Does the status hook need a vocabulary of its own for layout rules, or is the state
  enough? Phase 1's example hook will show.
- Does a view page need the composer? `timeline` without one is read-only, and the
  viewer already takes input. Leaving it out keeps the first cut small.

## Findings

None yet.
