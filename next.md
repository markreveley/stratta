---
type: handoff
updated: 2026-11-25
---

# Next

> This file's first open step is mirrored in direction's `repo-manifest.md`. Change it by asking an agent to run `update-next`. If you edit it by hand, run `update-next` afterwards.

## Next, in order

1. **(agent)** Run `update-next`. The steps below were edited by hand on 2026-11-25, so
   direction's `repo-manifest.md` may no longer mirror this file's first open step. Do it
   before acting on anything else here, and before editing this list again.
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

## Questions for the operator

- For pane threads, if holding a request blocks the pane, what should the default be:
  hold for a few seconds and then let the agent's own dialog take over, or hold until
  answered through Stratta? Undecided as of 2026-11-25. Step 3 tells whether the question
  arises at all, so it can wait for those findings.

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
- Five plans are written and not started: [`plans/slash-commands.md`](plans/slash-commands.md),
  [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md),
  [`plans/code-mode-orchestrator.md`](plans/code-mode-orchestrator.md),
  [`plans/terminal-hyperlinks.md`](plans/terminal-hyperlinks.md) and
  [`plans/composer-editing.md`](plans/composer-editing.md). The last two are both terminal
  client only and both touch `Stratta.TUI.Render`; neither blocks anything.

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
