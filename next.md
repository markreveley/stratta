---
type: handoff
updated: 2026-11-25
---

# Next

> This file's first open step is mirrored in direction's `repo-manifest.md`. Change it by asking an agent to run `update-next`. If you edit it by hand, run `update-next` afterwards.

## Next, in order

1. **(operator)** Send the report from your first runs on your own machine (2026-11-25).
   The points that are still unknown here: which agent you ran and whether a real agent
   has been run at all; whether `mix setup` worked from Hex (it has only been built from
   local checkouts); whether ctrl-c and ctrl-s behave in `stratta attach` on your system;
   and how your terminal's tab shows a thread's status while `stratta attach` or
   `stratta watch` is open.
2. **(agent)** Phases 1 and 2 of [`plans/gui-first.md`](plans/gui-first.md): notifications
   and the tab title, the follow switch, then the command language in the daemon and the
   command bar in the app. Not blocked on anything; tested against the demo agent, with a
   look at notifications in a real browser.
3. **(agent)** Phases 1 to 3 of [`plans/slash-commands.md`](plans/slash-commands.md): keep
   the list of slash commands an agent advertises, add `stratta commands`, and suggest
   commands in the viewer's and the app's composer. Not blocked on anything; tested
   against the demo agent.
4. **(agent)** Phase 3 of the gui-first plan: the file list and the Markdown editor.
5. **(agent, blocked on operator)** Phase 0 of
   [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md): the spike that
   answers whether Claude Code still shows its own permission dialog while a
   `PermissionRequest` hook holds the request, and the six smaller questions listed
   there. It needs a session on a machine with Claude Code 2.1.295 or later, signed in.
   Write the findings into the plan's last section. In the same session, do Phase 4 of
   the slash-commands plan (what real agents advertise).
6. **(agent)** Phase 1 of the pane-threads plan: requests only (`stratta run`,
   `stratta hook`, `Stratta.PaneThread`), including the check that stops an agent from
   approving its own requests. Start only after step 5's findings are in.
7. **(agent)** Phase 0 of [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md):
   describe every `Stratta.API` operation (arguments, result, one line, read-only or not),
   add `stratta ops`, and a test that fails when an operation has no spec. Useful on its
   own as reference; the later phases (a sandbox where an orchestrating model writes code
   against Stratta) wait until there is an orchestrating model.
8. **(agent)** [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md): one OSC 8
   link primitive in `Stratta.TUI.Render`, then the links Stratta generates itself (PR
   URLs, diff file paths). Small, independent of everything else, and the width-accounting
   tests in Phase 1 are the part that matters.
9. **(agent)** [`plans/composer-editing.md`](plans/composer-editing.md): a wrapped,
   cursor-editable composer in the viewer, replacing the append-only single line. Do it
   after step 3, because both it and the slash-commands plan want the composer's arrow
   keys and the second one in should follow the first one's precedence rule.
10. **(agent)** Phase 4 of the gui-first plan: the login, then a shell for each thread in
    the app. Begins with the spike listed there.
11. **(agent, blocked on operator)** Phase 5 of the gui-first plan: remote hosts over SSH.
    Begins with a check that needs two machines: the terminal client against a forwarded
    socket, and the app through a forwarded port. Neither has been tried.

## Questions for the operator

- For pane threads, if holding a request blocks the pane, what should the default be:
  hold for a few seconds and then let the agent's own dialog take over, or hold until
  answered through Stratta? Undecided as of 2026-11-25. Step 5 tells whether the question
  arises at all, so it can wait for those findings.
- On a remote host, is `dev:2a` the right name for a request (host first, then slot and
  letter), or should slot numbers be shared across hosts so they stay unique? Needed
  before step 11, not before.
- Is the order above right? The first two phases of the app-first plan are placed ahead
  of slash commands and pane threads because that is where the first day of use pointed.
  Steps 2 to 4 and 7 to 9 do not depend on each other, apart from 9 following 3.

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
- Not yet confirmed by a recorded run: real agents; installing dependencies from Hex; the viewer's
  ctrl-c and ctrl-s handling on macOS (it relies on `ps` and `stty` and was run on Linux
  only); how a terminal that draws OSC 7501 presents the dashboard's per-thread records.
- [`docs/app-and-terminal.md`](docs/app-and-terminal.md) maps every task onto both front
  ends.
- Decision (2026-11-24): nothing in this repository, files or commit messages, names a
  product other than Jido and the agents Stratta runs. Terminal-specific glue (window
  layouts, status-line hooks) is kept outside it on purpose; the client only offers the
  neutral hooks `STRATTA_OPENER` and `STRATTA_STATUS_HOOK`. Keep new work to that rule.
- Six plans are written and not started: [`plans/gui-first.md`](plans/gui-first.md),
  [`plans/slash-commands.md`](plans/slash-commands.md),
  [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md),
  [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md),
  [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md) and
  [`plans/composer-editing.md`](plans/composer-editing.md). The last two are both terminal
  client only and both touch `Stratta.TUI.Render`; neither blocks anything.
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
