# Stratta in the terminal

`stratta` is a client for a running Stratta daemon (the [core](../core/), or the GUI,
which includes it). It is one self-contained escript in pure Elixir: no native code and
no dependencies beyond Erlang/OTP 28.

```sh
mix setup            # builds ./stratta; put it on your PATH
stratta help
```

## Slots, requests and the current thread

Three small ideas keep commands short.

- **Slots.** Every thread sits in a numbered slot, shown in the `#` column of
  `stratta ls`, and is called by that number: `stratta diff 2`. A new thread takes the
  lowest free slot. Slots never shift on their own; `stratta slot THREAD N` moves a
  thread (swapping with whoever is there) and `stratta unslot THREAD` frees its slot
  while keeping the thread, which still answers to its id.
- **Request names.** A permission request is named by its thread's slot and a letter:
  `2a`, then `2b`. `stratta approve 2a` answers exactly that one. Letters are never
  reused within a thread, so a name that was already answered is refused and can never
  fall through to a newer request.
- **The current thread.** Commands that name no thread act on the current one, set by
  `stratta use N` and by `stratta new`. It lives in the daemon, per workspace
  (`$STRATTA_WORKSPACE`, one shared workspace by default), so every shell and dashboard
  in a workspace agrees on it. `$STRATTA_THREAD` overrides it for one shell.

## The dashboard

`stratta watch` is the pane to leave open beside a shell. It lists every slotted thread
and every request waiting on you, and follows the current thread underneath.

```
Stratta · 2 threads · 0 working · 2 waiting on you
Threads                                        Waiting on you
›  1 ⚠ create a notes file  demo                 1a  Edit STRATTA_DEMO.md
   2 ⚠ edit the readme  demo                     2a  Edit STRATTA_DEMO.md
── 1 · create a notes file · demo · needs approval ──────────────────────
› create a notes file
Plan
  ✓ Inspect the workspace
  ◐ Make the requested change
⌕ List files in workspace  completed
✎ Edit STRATTA_DEMO.md  pending
⚠ 1a Edit STRATTA_DEMO.md — waiting for you
  +Request: create a notes file
```

Run commands in the other pane and it keeps up: `stratta use 2` switches the lower half
to thread 2, `stratta send "…"` streams there, `stratta approve 1a` clears the request.
In the dashboard itself, ↑, ↓ or a digit selects a thread, which makes it current for the
other pane too. Enter opens it in the viewer; `c` clears the finished marks; `q` quits.

## The viewer

`stratta attach N` (or `stratta new --attach "…"`) follows one thread live, with a
composer.

```
● 1 please create a file · demo · ⑂ stratta/demo-5op4Dz
› please create a file
∴ The user asked: "please create a file". Let me look at the workspace first, then
∴ decide what to do.
Plan
  ✓ Inspect the workspace
  ◐ Make the requested change
  ○ Summarize
⌕ List files in workspace  completed
  │ README.md
✎ Edit STRATTA_DEMO.md  pending
⚠ 1a Edit STRATTA_DEMO.md — waiting for you
  STRATTA_DEMO.md
  +## 2026-11-24 14:41:29
  +
  +Request: please create a file

⚠ 1a Edit STRATTA_DEMO.md  y approve  n deny
› Queue a follow-up…
enter queue · alt-enter steer · esc stop · pgup/pgdn scroll · ctrl-d detach
```

| key | does |
| --- | --- |
| enter | send the message; while a turn is running it is queued behind it |
| alt-enter or ctrl-s | steer: inject the message into the running turn |
| `y` / `n` | approve / deny, when a request is waiting and the composer is empty |
| esc | interrupt the running turn |
| pgup / pgdn / ↑ / ↓ / end | scroll; end follows the latest output again |
| ctrl-c | interrupt if busy, else clear the composer, else detach |
| ctrl-d | detach |

The viewer holds no agent state. Detaching leaves the thread running in the daemon, and
any number of viewers, and the GUI, can watch the same thread.

`stratta diff N --watch` is a third view: the thread's changes against its base commit,
refreshed when the agent finishes a tool call or a turn.

## Commands

Everything the views do is also a one-shot command, so scripts and key bindings can drive
threads: `new`, `use`, `send`, `approve`, `deny`, `stop`, `status`, `model`, `handoff`,
`slot`, `unslot`, `commit`, `push`, `ship`, `rm`, `ls`, `agents`, `projects`. Most take
`--json`. See `stratta help`.

`stratta send` reads a leading number as a slot (`stratta send 2 "…"`); otherwise every
word is text for the current thread. Use `-t THREAD` to be explicit.

Exit status: 0 success, 1 the daemon refused or failed, 2 bad usage, 4 no daemon.

## Telling the terminal what the agent is doing

A viewer reports its thread's state so the terminal can show it outside the pane, on a
tab or in a list of sessions:

| state | when |
| --- | --- |
| `working` | a turn is running; the message is the tool in progress |
| `blocked`, kind `permission` | a permission request is waiting; the message is its title |
| `done` | a turn finished and you have not pressed a key in the viewer since |
| `error` | the turn or the session failed |
| `idle` | otherwise |

It is sent three ways at once:

1. **OSC 7501** program status reports, which carry the state, the kind and one line of
   text. `stratta watch` reports one record per thread (`thread/<id>`) plus an aggregate.
2. **OSC 9;4** progress reports, a coarser busy / paused / error indicator that more
   terminals draw today.
3. **`STRATTA_STATUS_HOOK`**, a shell command run on every change with `STRATTA_STATE`,
   `STRATTA_KIND`, `STRATTA_MESSAGE`, `STRATTA_THREAD` and `STRATTA_TITLE` set. Use it
   where escape sequences do not reach: a multiplexer's status line, a desktop
   notification, a push to your phone.

Terminals ignore sequences they do not know, so all of this is safe everywhere.
`--bell` on `attach` also rings the bell when a request starts waiting.

These reports are one-way summaries. Answers go back through the daemon (`y` in the
viewer, or `stratta approve`), which is what actually resolves the agent's request.

## Windows and splits

Stratta does not know how your terminal makes windows. `stratta open THREAD` (and enter
in the dashboard) runs `$STRATTA_OPENER` if it is set, with `STRATTA_THREAD`,
`STRATTA_TITLE`, `STRATTA_CWD` and `STRATTA_BIN` in its environment, and otherwise
attaches in the current terminal. An opener is a few lines of shell that ask your
terminal for a window running `"$STRATTA_BIN" attach "$STRATTA_THREAD"` and a split
running `"$STRATTA_BIN" diff --watch "$STRATTA_THREAD"`.

## How it is built

| module | role |
| --- | --- |
| `Stratta.TUI.Client` | the socket protocol |
| `Stratta.TUI.Term` | raw mode, alternate screen, size, input reader |
| `Stratta.TUI.Keys` | bytes to key events, including bracketed paste |
| `Stratta.TUI.Render` | pure: thread items to styled lines, lines to a frame |
| `Stratta.TUI.App` | the loop shared by the views |
| `Stratta.TUI.Dashboard`, `Viewer`, `DiffView` | the three views |
| `Stratta.TUI.Status` | status reports and the status hook |
| `Stratta.TUI.Open` | the opener hook |
| `Stratta.TUI.CLI` | commands |

Known limits: the composer is a single line with no cursor movement, and column widths
assume one cell per character, so wide characters (CJK, emoji) can misalign a line.
