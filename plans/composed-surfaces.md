---
type: plan
status: proposed
created: 2026-11-26
---

# Views as separate programs: Stratta as a guest in the host terminal

## Summary

Stratta has two front ends, and each new thing to look at is added to one or both by hand.
This plan adds a third way for a view to exist: as its own small program, a client of the
daemon's socket, started by a shell command and placed by whatever hosts the operator's
terminal. A view of this kind can be a text program, a page of the app shown by a browser
that draws in a terminal pane, or a graphical program drawn with a pixel toolkit for
terminals.

The idea is not new to this repository. The opener (`STRATTA_OPENER`), the status hook
(`STRATTA_STATUS_HOOK`), the status reports and `stratta diff --watch` already treat
Stratta as one program among several in a layout it does not own. This plan finishes that
thought: views get names an opener can ask for, the app's views get addresses, the socket
protocol becomes a documented interface, and the first graphical view is built outside
`core/`, `gui/` and `tui/`.

The test of whether it is worth doing: **a new view should cost one program and no change
to `core/`.** If the first one needs more from the daemon than a subscription, the socket
is not yet the interface this plan assumes, and that is the finding to write down.

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
- **Addresses in the app.** The router has `/`, `/t/:thread_id` and `/providers`. The diff
  and ship panels are state inside the thread page, so there is no address that opens a
  thread with its diff showing.
- **The daemon knows nothing about panes**, windows or what is on screen. Neither front
  end reports it.
- **Every client is Elixir.** Nothing in another language has spoken the socket.

## Design

### 1. A view is a name, a thread and a way to start it

- The views Stratta can name: `attach`, `diff`, `dashboard`, `app` (the thread's page in
  the app), and later `shell` and `files` from the [app-first plan](gui-first.md).
- `stratta open N --view NAME` passes `STRATTA_VIEW` to the opener, and `STRATTA_URL` when
  the view is a page of the app. With no `--view`, behaviour is as today.
- The app-first plan's command language already separates operations from "view commands
  that only a front end can carry out" (`diff`, `files`, `shell`, `open 3`). This plan
  gives those a third place to be carried out: handed to the opener. The parser stays in
  the daemon, as that plan's Design 2 says; nothing is parsed twice.

### 2. The app's views have addresses

- A thread page takes a panel in its address, so `/t/<id>?panel=diff` opens with the diff
  showing. Any view worth putting in a pane of its own should be reachable this way.
- A new operation, `app.url`, returns the address of the app for a thread and panel, or
  says that no app is running in this daemon. The terminal client does not guess a port.

### 3. The daemon still does not know the layout

- No operation reports panes, and none is added. The host terminal knows what is open and
  where. The opener and the status hook are where its knowledge and Stratta's meet, and
  both belong to the operator.
- Rules about what should be visible when ("show the diff while a thread waits on a
  request, close it when the thread resumes") are a status hook. This plan ships one as
  an example and adds nothing to make it possible, because nothing is missing.
- A consequence to state plainly: Stratta cannot close a view it opened. The opener's
  script can, if the host lets it address a pane by a name the script chose.

### 4. The socket is a public interface

- A document, `docs/socket-protocol.md`: framing, request and reply, pushes, coalescing,
  errors. Written from the code, with the moduledoc pointing at it.
- A protocol version in `ping`, as the app-first plan's Design 8 already requires for
  remote hosts. One number, shared.
- A client in a second language, small enough to read in a sitting, kept in the
  repository as the proof that the document is sufficient.

### 5. A graphical view is a program beside the three folders

- A fourth folder, `views/`, one folder per view, each with its own build. A view depends
  on the socket protocol and on nothing in `core/`, `gui/` or `tui/`.
- A view that needs a toolchain the rest of the repository does not (another language, a
  native build) keeps it inside its own folder. `tui/` stays one escript in pure Elixir.
- The first one is chosen by what data exists when the phase is reached. Decision timing
  from [the telemetry plan](decision-telemetry.md) is the likely candidate; the claims
  view from [the claim-graph plan](claim-graph.md) is the other.

### 6. A browser pane showing the app is a second route to an answer

[Authority for an answer](delegated-authority.md) Phase 0 reproduces an agent approving
another thread's request through a shell command. A browser that an agent can drive, when
it is showing the app, is the same hole by another door: the agent presses Approve. The
app has no login, so nothing stops it today.

- That plan's Phase 0 gains a second reproduction: an agent-driven browser answering a
  request in the app.
- Its Phase 1 grant has to cover the app's session as well as the socket, which the
  app-first plan's Design 7 already implies. Until then, the documentation for the `app`
  view says so.

## Phases

### Phase 0: look, with no code (operator; needs nothing)

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

Write what was seen into Findings. Much of this is the same sitting as step 1 of
`next.md`.

### Phase 1: named views and addresses (small; needs nothing)

`--view` and `STRATTA_VIEW`, the panel in the thread page's address, `app.url`, and
`STRATTA_URL`. Two example openers in `tui/README.md` written against a host's
command-line interface in general terms, and one example status hook that opens and
closes a diff view. Tests: the opener's environment for each view; the address round trip
in the app.

### Phase 2: the protocol document and a second client (small; needs nothing)

`docs/socket-protocol.md`, the protocol version in `ping`, and a client in another
language that lists threads and follows one. A test in `core/` runs it against a real
daemon when its runtime is present and is skipped when it is not.

### Phase 3: the second reproduction (small; with step 5 of `next.md`)

The agent-driven browser answering a request, as a test or, if it cannot be automated in
the suite, as a written procedure with its result. Belongs with the authority plan's
Phase 0.

### Phase 4: the first graphical view (medium; needs Phase 2 and step 3 or step 15 of `next.md`)

One view in `views/`, with its build, its README and a line in the root README's layout
table. Measured against the summary's test: list every change it needed outside its own
folder.

### Phase 5: a guest inside the viewer (a spike; needs Phase 4)

Whether the viewer can give part of its screen to a graphical guest, speaking the guest
toolkit's embedding protocol from Elixir, with no native code in `tui/`. A yes or no with
the reason, not a feature.

## Not in scope

- A third complete front end. Nothing here repeats the timeline, the composer or
  approvals in another toolkit.
- The daemon tracking, opening or closing panes.
- Naming or detecting a terminal.
- Replacing the app or the terminal client.

## Open questions

- Should `views/` live in this repository at all, or should a view be its own repository
  that depends on the protocol document? One repository is simpler to test; separate ones
  prove the interface harder.
- Does the status hook need a `STRATTA_VIEW`-style vocabulary of its own for layout rules,
  or is the state enough? Phase 1's example hook will show.
- Is one protocol version enough, or do pushes and operations age at different rates?

## Findings

None yet.
