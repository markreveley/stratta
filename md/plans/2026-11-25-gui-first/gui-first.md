---
type: plan
kind: need
---

# The app first: commands, files, a shell and remote hosts in the app

> Status: proposed · 2026-11-27

## Summary

After a first day of use, the app is the nicer place to work and the terminal client is
the more capable one. This plan closes that gap from the app's side. It adds to the app:

- notifications, and a way to follow the current thread;
- a command bar that speaks the same language as the `stratta` command;
- a file list and a Markdown editor for each thread's folder;
- a shell for each thread, in the page;
- other machines: one app that shows and drives threads on remote hosts over SSH.

The terminal client stays. It becomes one of two front ends that speak one command
language to the same daemon, and it remains the way to work where no browser is at hand.

Nothing here is built. The order of the phases is by cost and by what later phases stand
on, and each phase is usable without the ones after it.

## Why this exists

Kind: **need**, observed, and set aside.

Written from the operator's first day of use, 2026-11-25: the app was the nicer place to
work and the terminal client the more capable one. On 2026-11-26 the operator chose to
work in a host terminal instead, with the app taken apart into views
([views as separate programs](../2026-11-26-composed-surfaces/composed-surfaces.md)). The observation stands. The remedy
changed, so this plan waits, and returns to test that direction against a front end that
hosts everything itself.

## What exists today

Checked in the code on 2026-11-25:

- **The app calls the core directly.** `StrattaWeb.AppLive` calls `Stratta.Threads`,
  `Stratta.ThreadServer` and `Stratta.Providers` as Elixir functions and subscribes to
  `Stratta.PubSub`. It does not go through `Stratta.API` or the socket. That only works
  because the app and the daemon run in one node on one machine.
- **The terminal client goes through the socket.** Every `stratta` command is a
  `Stratta.API` operation sent over the Unix socket. The path of the socket can be set
  with `STRATTA_SOCKET`.
- **The command language lives in the terminal client.** `Stratta.TUI.CLI` parses
  `approve 2a`, `use 3`, `send 2 …` and turns them into operations. The daemon knows
  operations, not command lines.
- **The app does not know the current thread.** `stratta use 2` sets the current thread
  in the daemon and the dashboard follows it. The app shows whichever thread was clicked,
  and a click there does not set the current thread.
- **The app has no notifications** and does not change the tab's title.
- **The app has no login.** It listens on `127.0.0.1` only. Any user or program on the
  machine that can reach the port can use it. Origin checking is off in the development
  configuration.
- **The process helper can open pseudo-terminals.** `Jido.Harness.Process.Spec` has a
  `pty` option, and the bundled native helper has a call to set the window size. Stratta
  does not use either yet.
- **The app has no build step for scripts.** The page's script is one static file.

## Design

### 1. Everything the app does goes through `Stratta.API`

This is the decision the rest depends on. If the app uses only operations and
subscriptions that also exist on the socket, then where the daemon runs stops mattering:
the same app can show a daemon in its own node or a daemon on another machine.

- New features in this plan are written as `Stratta.API` operations from the start.
- The app gets a small client layer with two implementations: one that calls the daemon
  in the same node, and one that speaks the socket protocol. Existing direct calls move
  behind it in Phase 5; until then they keep working.

### 2. One command language, kept in the daemon

- A new module in `core/` parses a command line into either an operation (`approve 2a`,
  `send 2 fix the test`, `use 3`, `ship`) or a view command that only a front end can
  carry out (`diff`, `files`, `shell`, `open 3`).
- A new operation runs a line: `command.run` with the text and the workspace. It returns
  the result of the operation, or the view command for the front end to act on.
- The app's command bar sends lines to it. The `stratta` command keeps its flags and exit
  codes and uses the same parser, so both accept the same words.
- A file of command lines is a script. `source FILE` runs one, from the command bar or as
  `stratta source FILE`. Lines run in order and stop at the first failure.
- A key binding is a command line with a key attached, read from a file in the data
  directory.

`stratta run` is taken by the pane-threads plan, which is why the script command is
`source`.

Phase 0 of [`code-mode-orchestrator.md`](../2026-11-25-code-mode-orchestrator/code-mode-orchestrator.md) adds a spec for every
operation (arguments, result, read-only or not). If that is done first, the parser's
argument checks and the command bar's help come from those specs rather than being
written twice. The two plans also meet later: a script of command lines is the simple
form of what that plan gives a model.

### 3. Notifications are the app's version of status in the terminal

- The page asks for permission when the user clicks a "turn on notifications" button, not
  on load.
- A notification is sent when a thread starts waiting on a request, and when a thread
  finishes a turn, if the page is not in front or is showing another thread. Clicking it
  shows that thread.
- The tab's title carries the number of threads waiting: `(2) Stratta`.
- This works only while a page is open. With no page open, the terminal client's status
  hook is still the way to be told.

### 4. Following the current thread

- A "follow" switch in the app, off by default. When on, the app shows the workspace's
  current thread and changes with it, and choosing a thread in the app sets the current
  thread. `use 3` in the command bar does the same as in the terminal.
- With the switch off, the app behaves as it does today.

### 5. Files: a list and a Markdown editor, not an IDE

- Operations: `files.list` (a thread's folder, one level at a time), `file.read`,
  `file.write`.
- Limited to text files under a size limit, inside the thread's folder. The path is
  resolved before use, so a symbolic link or `..` that leads outside the folder is
  refused.
- `file.write` carries a hash of the content that was read. If the file has changed
  since, the write is refused and the current content comes back, so the app can show
  both versions. This is what protects against the agent and the user editing one file.
- The editor is a text area with a rendered preview beside it, using the Markdown
  renderer the app already has. No syntax tools, no multiple cursors, no project search.
- While the thread's agent is working, the editor says so.

### 6. A shell for each thread

- A new process in `core/` owns one pseudo-terminal per shell, started in the thread's
  folder with the user's login shell, through the process helper.
- Operations: `shell.open`, `shell.input`, `shell.resize`, `shell.close`, and a
  subscription that pushes output. The daemon keeps a bounded scrollback, so closing the
  page does not end the shell and reopening it shows where it was.
- In the app: a terminal emulator widget for web pages (xterm.js is the usual one), added as
  a static file like the rest of the page's script.
- In the terminal: `stratta shell [THREAD]` attaches to the same shell. Cheap once the
  operations exist.
- This is a real shell on the machine, as the user. A thread's folder is an ordinary
  folder, not an isolated environment, and the shell is not confined to it.
- It can host a pane thread: `stratta run` from the pane-threads plan would work inside
  it, which brings an agent's own interface into the app.

### 7. A login before the shell

A shell in a web page raises the cost of the missing login from "someone can read my
threads" to "someone can run commands as me". So Phase 4 starts with:

- A token created on first start and stored in the data directory, readable only by the
  user. `stratta token` prints it. The app asks for it once and then keeps a session.
- Origin checking on in every configuration.
- The shell's operations refused on a connection without a session.

Listening on anything other than `127.0.0.1` stays out of scope. Reaching the app from
another machine is done with a tunnel.

### 8. Remote hosts

The daemon does the work that touches a thread's folder: it starts the agent, runs git,
reads files and owns the shell. So a remote host means "a daemon on that machine", and
the app needs only a way to reach its socket.

- **Reaching it:** SSH can forward a Unix socket: `ssh -N -L LOCAL.sock:REMOTE.sock
  HOST`. The app keeps a list of hosts and runs one such `ssh` process per remote host.
  It uses the user's own SSH configuration, keys and agent. Stratta never sees a password
  or a key.
- **In the app:** the sidebar groups threads by host. Everything else, including the
  shell, the files and the diff, works for a remote thread without further work, because
  the remote daemon does it and sends the result.
- **On the remote machine:** `core/` only, started with `mix run --no-halt`. No app is
  needed there.
- **Names:** slots belong to a daemon, so two hosts can each have a thread 2. A thread on
  a remote host is named with the host first: `dev:2`, and its request `dev:2a`. The
  local host needs no prefix.
- **Versions:** `ping` returns the daemon's version today. It gains a protocol version,
  and the app refuses a daemon whose protocol it does not speak, with a readable message.

Two things should already work without any of this, and are untested:

- The terminal client against a forwarded socket: forward the socket with `ssh -L`, then
  run `stratta` with `STRATTA_SOCKET` set to the local end.
- The app on the remote machine, reached through a forwarded port: `ssh -L
  4001:127.0.0.1:4001 HOST`.

**Considered and rejected:** keeping Stratta local and starting only the agent over SSH.
The agent's protocol runs over standard input and output, so it can be started through an
`ssh` command. But the thread's folder is then remote while the daemon is local, and
every part of the core that touches the folder (worktrees, diffs, commits, files, the
shell) would need a second, remote form.

## How it fits with the control-plane plans

Ten plans added on 2026-11-25 overlap this one in four places. Settled here rather than
left to whichever is built first:

- **The command language is the mechanism, not a duplicate.** Design 2 puts the parser and
  `command.run` in `core/`. [Surfaces drawn from behaviour](../2026-11-25-behaviour-shaped-ui/behaviour-shaped-ui.md) renders
  that language — a palette, a generated form per operation, and a rule for what applies
  now — and defines no second path to an operation. It also settles that plan's open
  question about sharing a module between `gui/` and `tui/`: neither front end holds the
  language, so nothing is shared.
- **The login in Design 7 and the local grant are one token.**
  [Authority for an answer](../2026-11-25-delegated-authority/delegated-authority.md) Phase 1 is the same thing with a wider
  job: a secret in the data directory that an answer must present. Build the grant and let
  the app's session hold one, rather than a session token here and a grant there.
- **Design 8 settles where a daemon runs.** A remote host means a daemon on that machine.
  [Where a thread's files and processes live](../2026-11-25-thread-environments/thread-environments.md) had that as an open
  question and now follows the same rule, so its environments need no second remote form
  for the shell, the files or the diff. Phase 0 of
  [remote access](../2026-11-25-remote-access/remote-access.md) is the check this plan's Phase 5 starts with.
- **The `source` restriction in Safety is temporary for a better reason than stated.**
  Phase 0 of the authority plan reproduces the approve-your-own-request hole as a test and
  Phase 1 closes it with a grant, which is what lets `source` accept `approve` lines again
  — under a grant that says which requests it may answer.

One ordering consequence worth naming: Phase 0 of
[code mode](../2026-11-25-code-mode-orchestrator/code-mode-orchestrator.md) is better done before Phase 2 here, as Design 2
already says, because then the parser's argument checks and the command bar's help come
from the operation specs instead of being written twice.

The shell and the editor act as the operator on real files, so neither produces a
[decision record](../2026-11-25-decision-records/decision-records.md) — those are for an agent's requests. A script that
answers a request is different: it is an automatic answer, and it has to name the rule or
the grant that permitted it like any other.

## Work

### Phase 1: notifications and following (small)

- Notifications and the tab title, from the thread-list events the app already receives.
- The follow switch, using the `current.get` and `current.set` operations and the
  `current` subscription.
- Tests for the events; the notification itself needs a look in a real browser.

Done when a thread that starts waiting raises a notification with the page in the
background, and `stratta use 2` in a terminal changes the thread shown in a following
app.

### Phase 2: the command language and the command bar (medium)

- The parser and `command.run` in `core/`, with tests for every command the terminal
  client has today.
- `Stratta.TUI.CLI` uses the parser for the commands that are operations.
- The command bar in the app: opened with a key, with history, showing the result or the
  error in place.
- `source FILE` in both front ends.
- The side-by-side guide ([`md/docs/app-and-terminal.md`](../../docs/app-and-terminal.md)) gets
  a section for it.

Done when `approve 2a` typed in the app's command bar answers a request, and a file of
three commands runs the same from the command bar and from `stratta source`.

### Phase 3: files and the Markdown editor (medium)

- `files.list`, `file.read`, `file.write` with the path and size checks and the hash.
- The files panel and the editor in the app.
- `files` and `edit PATH` as view commands.
- Tests: paths that leave the folder are refused, including through a symbolic link; a
  write over a changed file is refused and returns the new content.

Done when a Markdown file in a thread's folder can be opened, edited, previewed and
saved, and a save over a file the agent has just changed is refused with both versions
shown.

### Phase 4: login, then the shell (large)

Start with a spike, recorded in Findings:

- Does the helper's pseudo-terminal mode deliver bytes a terminal widget can draw without
  loss, including full-screen programs?
- Does setting the window size reach the program?
- What happens to open shells when the daemon stops, and should they be ended with it?
- Does an agent's own interface run correctly inside it?

Then:

- The token, the session, origin checking.
- The shell process in `core/`, its operations and the subscription.
- The terminal widget in the app; `stratta shell` in the terminal client.
- Tests driving a shell through the operations: run a command, read its output, resize,
  close, reattach and read the scrollback.

Done when a shell opened on a thread in the app runs a full-screen program correctly,
survives a page reload, and is refused without a session.

### Phase 5: remote hosts (large)

Start with a check on two real machines, recorded in Findings: the two untested paths
named in Design 8.

Then:

- Move the app's remaining direct calls behind the client layer.
- The socket implementation of the client layer.
- The list of hosts, the supervised `ssh` processes, and what the app shows when a host
  is unreachable or drops.
- Host prefixes in names, in the parser and in both front ends.
- The version check.
- Tests against a second daemon on the same machine with its own data directory, reached
  through its socket. The SSH step itself is checked by hand.

Done when one app shows threads from the local daemon and from a daemon on another
machine, and a message, an approval, a diff, a file edit and a shell all work on the
remote one.

### Phase 6: scripts in the app (small; after Phase 2)

- A scripts panel: files of commands kept in the data directory, in folders, with a
  description on the first line. Run one against the current thread, or bind it to a key.
- Shell scripts are run in a thread's shell, so they need Phase 4.

## Safety

- The shell and the editor act as the user, on real files. Neither is confined beyond the
  path checks in Design 5.
- The login in Design 7 is a condition for the shell, not an extra.
- An agent that runs as the user can call `stratta approve` on its own request today.
  The fix is planned in [`pane-threads-via-hooks.md`](../2026-11-25-pane-threads-via-hooks/pane-threads-via-hooks.md), Phase
  1, for both kinds of thread. A shell in the app does not change that risk, but a script
  that approves requests without a person looking adds to it. Until that fix is in,
  `source` refuses `approve` and `deny` lines.
- For remote hosts, access is what SSH grants. The forwarded socket's local end is
  created readable only by the user.

## Not in scope

- An editor for code: syntax tools, search across a project, refactoring.
- Listening on a network address, user accounts, or more than one person using one
  daemon.
- A packaged desktop app. Notifications with no page open would need one.
- Isolated environments for threads. A thread's folder stays an ordinary folder.
- Moving a thread from one host to another.

## Open questions

- Is `dev:2a` the right way to name things on a remote host, or should slots be shared
  across hosts so that numbers stay unique?
- Should the app's command bar open with one key while not typing, as in a modal editor,
  or only with a modified key?
- Should a thread's shell end when the thread is deleted? Proposed: yes.

## Findings

*To be filled in by the spike in Phase 4 and the check in Phase 5.*
