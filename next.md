---
type: handoff
updated: 2026-11-25
---

# Next

> This file's first open step is mirrored in direction's `repo-manifest.md`. Change it by asking an agent to run `update-next`. If you edit it by hand, run `update-next` afterwards.

## Next, in order

1. **(operator)** Run Stratta on your own machine with a real agent. Nothing here has been
   run against one yet. With Elixir 1.19+ on OTP 28+ installed: `cd gui && mix setup &&
   mix phx.server`, then `cd tui && mix setup` and put `tui/stratta` on your PATH. In a
   git repository run `stratta agents` to see which agents are ready, then
   `stratta new -a claude --attach "say hello"`. Note whether `mix setup` worked from Hex
   (it has only been built from local checkouts), and whether your terminal's tab shows
   the thread's status while `stratta attach` or `stratta watch` is open.
2. **(agent, blocked on operator)** Phase 0 of
   [`plans/pane-threads-via-hooks.md`](plans/pane-threads-via-hooks.md): the spike that
   answers whether Claude Code still shows its own permission dialog while a
   `PermissionRequest` hook holds the request, and the six smaller questions listed
   there. It needs a session on a machine with Claude Code 2.1.295 or later, signed in.
   Write the findings into the plan's last section.
3. **(agent)** Phase 1 of the same plan: pane threads with requests only (`stratta run`,
   `stratta hook`, `Stratta.PaneThread`), including the check that stops an agent from
   approving its own requests. Start only after step 2's findings are in.

## Questions for the operator

- Slash commands already reach an agent when sent as a message (`stratta send "/name"`),
  but Stratta drops the list of commands the agent advertises. Do you want a
  `stratta commands N` listing, and suggestions in the app's composer?
- For pane threads, if holding a request blocks the pane (step 2 will tell), is "hold for
  a few seconds, then let the agent's own dialog take over" the right default?

## State

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
- Terminal-specific glue (window layouts, status-line hooks) is kept outside this
  repository on purpose. The client only offers the neutral hooks `STRATTA_OPENER` and
  `STRATTA_STATUS_HOOK`.

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
