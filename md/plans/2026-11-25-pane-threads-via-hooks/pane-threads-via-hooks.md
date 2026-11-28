---
type: plan
kind: experiment
---

# Pane threads: the agent's own interface, with approvals through Stratta

> Status: proposed · 2026-11-27

## Summary

Today every Stratta thread is **headless**: the daemon starts the agent in its protocol
mode and Stratta draws everything. That gives full structure (named requests, diffs, a
timeline) but not the agent's own terminal interface.

This plan adds a second kind of thread, a **pane thread**: the agent's real terminal
interface runs in a pane you look at, and the agent's **hooks** report to the Stratta
daemon. The first target is Claude Code, whose `PermissionRequest` hook can hand a
permission decision to an outside program. With that, a request raised inside the agent's
own interface becomes `2a` in Stratta like any other, and can be answered from the
dashboard, from `stratta approve 2a` in another pane, or from the app.

The plan starts with a short spike, because one documented gap decides the design: whether
the agent still shows its own permission dialog while a hook is holding the request.

## Why this exists

Kind: **experiment**, gated by its spike, and central to the direction chosen on
2026-11-26.

A pane thread is how an agent's own interface becomes a pane in the host terminal, Rex
first. The reason given below is a preference: the agent's own commands, pickers and
layout, which a headless thread gives up. It has not been tested against use. Whether it
can work at all turns on one fact the spike finds out.

## Why

| | Headless thread (today) | Pane thread (this plan) |
| --- | --- | --- |
| Where the agent runs | In the daemon, no terminal | In a terminal pane you opened |
| What you look at | Stratta's viewer, dashboard or app | The agent's own interface, plus Stratta's dashboard and app |
| The agent's own features (its commands, pickers, layout) | Only what its protocol mode offers | All of them |
| Permission requests as data, named `2a` | Yes | Yes, through the hook |
| Status in the terminal | Stratta's views report it | The agent reports it itself (Claude Code sends OSC 7501 from 2.1.295), and Stratta knows it from hooks |
| Full timeline in Stratta | Yes | Partial, built from hook events |
| Send, steer, stop from Stratta | Yes | Not in the first phases (see Phase 4) |
| Diff, commit, push, ship | Yes | Yes; they only need the working folder |
| Survives closing the terminal | Yes | No; the agent lives in the pane |

Pane threads do not replace headless ones. They are for when you want to sit in the
agent's interface and still have one place that knows what every agent is waiting for.

## How it works

```
 pane                                        daemon (core)
┌──────────────────────────────┐            ┌─────────────────────────────────┐
│ stratta run -a claude        │  register  │ PaneThread (one per pane thread)│
│  └─ registers, then starts   │──────────► │  slot, id, working folder       │
│     the agent with hooks     │            │  timeline from hook events      │
│     added for this run only  │            │  pending requests, labelled a,b │
│                              │            │                                 │
│ agent's own interface        │   hooks    │                                 │
│  ├─ SessionStart ────────────┼──────────► │ bind the agent's session id     │
│  ├─ UserPromptSubmit ────────┼──────────► │ user message, "working"         │
│  ├─ PermissionRequest ───────┼──────────► │ new request 2a; hold the call   │
│  │      ◄── allow / deny ────┼─────────── │ ◄─ stratta approve 2a, the app  │
│  ├─ Stop ────────────────────┼──────────► │ last reply, "idle"              │
│  └─ SessionEnd ──────────────┼──────────► │ thread ended                    │
└──────────────────────────────┘            └─────────────────────────────────┘
          each hook is `stratta hook <event>`, a short-lived client
          that talks to the daemon over the existing Unix socket
```

1. **Launch.** `stratta run -a claude [-- agent arguments]` is run in the pane. It
   registers a pane thread with the daemon (taking a slot, becoming the current thread),
   then starts the agent with Stratta's hooks added for that run only. Your own agent
   settings files are not edited.
2. **Hooks.** Each hook is a command, `stratta hook <event>`, that reads the event's JSON
   on standard input and forwards it to the daemon over the control socket.
3. **Requests.** For `PermissionRequest`, the hook does not return at once. The daemon
   records the request as an approval item with the next letter, exactly like a headless
   thread's, and holds the hook's call open. When someone answers, the daemon replies and
   the hook prints the decision in the agent's hook format. If nobody answers in time, the
   hook returns no decision and the agent carries on with its own dialog.
4. **Everything else in Stratta is unchanged.** A pane thread produces the same snapshot
   shape as a headless one, so the dashboard, `stratta ls`, `stratta status`,
   `stratta approve`, the app's request card, and diff, commit and ship all work without
   knowing which kind of thread they are showing.

## What the agent's hooks provide

From the Claude Code hooks reference (<https://code.claude.com/docs/en/hooks>), read on
2026-11-25. Items marked *verify* are what the spike must confirm on a real install.

- **`PermissionRequest`** runs when the agent is about to ask for permission. Its input has
  `tool_name`, `tool_input`, an optional `permission_suggestions` list, and the fields
  every hook gets (`session_id`, `cwd`, `transcript_path`, `permission_mode`). It has no
  `tool_use_id`.
- **Its answer** is JSON: `hookSpecificOutput.decision.behavior` of `allow` or `deny`.
  With allow it may also carry `updatedInput` and `updatedPermissions` (which is how
  "always allow this" can be expressed). With deny it may carry a `message` for the agent
  and `interrupt: true` to stop it. The agent's own deny rules still apply after an allow.
- **No decision** leaves the agent's normal permission flow unchanged.
- **Hook kinds.** `command` and `http` both exist. Command and HTTP hooks default to a
  600 second timeout, set per hook with `timeout`. The maximum is not documented. *verify*
- **Other events** useful here: `SessionStart` (also on resume and clear),
  `UserPromptSubmit` (the prompt text), `Stop` (includes the last assistant message),
  `SessionEnd`, `PostToolUse`, and `Notification` (its `permission_prompt` type fires
  after about six seconds without typing).
- **Where hooks live.** Settings files at user and project level, and plugins. Adding
  hooks for one run through the `--settings` flag is how this plan avoids editing your
  files. *verify*
- **Not documented:** whether the agent shows its own dialog while a `PermissionRequest`
  hook is still running, or only after it returns. The reference says only that where
  another permission host exists, hooks run alongside it and the first decision wins.
  *verify; this is the main question of the spike*

## Design decisions

- **Command hooks over the Unix socket, not HTTP.** An HTTP hook would need the daemon to
  listen on a TCP port. The control socket already exists, is private to its owner, and
  keeps the rule that nothing is opened on the network. The cost is starting the client
  once per hook event (a few hundred milliseconds), so only the events above are hooked,
  and `PostToolUse` is added later as a background hook if it is wanted at all.
- **A second thread implementation behind the same snapshot.** `Stratta.PaneThread` sits
  beside `Stratta.ThreadServer`. Both keep a `Stratta.Timeline`, both answer
  `respond_approval`, both broadcast the same snapshot. The thread record gains
  `"kind" => "pane"`. Callers pick the module by kind in one place.
- **Requests are held in the daemon.** The hook client makes one socket call,
  `hook.permission`, which returns when the request is answered or when its wait runs out.
  The wait is set just under the hook's own timeout so the client always prints a clean
  "no decision" and is never killed mid-call.
- **Agent-neutral on the daemon side.** `hook.permission` takes a tool name, an input and
  a working folder, not Claude Code's JSON. The translation lives in the client
  (`stratta hook`), one small module per agent, so another agent with an equivalent hook
  needs only a new translator.
- **A small launcher script, not the escript, starts the agent.** A BEAM program cannot
  hand its terminal to a child process, so `stratta run` prints the environment and the
  command, and a few lines of shell `exec` the agent with them. That keeps the agent
  attached directly to the pane.

## The open question that shapes everything

While a hook holds a permission request, what does the person sitting at the pane see?

- **If the agent shows its dialog at the same time and the first answer wins:** ideal.
  Answer in the pane or in Stratta, whichever is nearer. Stratta marks the request
  resolved when the hook call is cancelled.
- **If the dialog appears only after the hook returns:** holding the request blocks the
  pane. Then a pane thread needs a choice, per thread and changeable while it runs:
  - *remote first:* hold until answered through Stratta or until the wait runs out;
  - *local first:* hold for a few seconds, then let the agent's dialog take over;
  - *policy only:* never hold; answer what a rule covers (Phase 3) and pass the rest to
    the agent's dialog at once.

  The default would be local first with a short hold, so a pane never looks stuck.

## Phases

### Phase 0: spike (small; needs a machine with Claude Code 2.1.295 or later, signed in)

A throwaway hook script and no Stratta changes. Answer, and write the findings into this
file:

1. Does the agent's own dialog show while a `PermissionRequest` hook is running?
2. What does the pane show during a long-running hook, and does the agent's terminal
   status say "blocked" during it or only once its dialog is up?
3. Do hooks passed with `--settings` for one run merge with the user's own hooks?
4. Real `PermissionRequest` inputs for a file edit, a new file, a shell command and an
   MCP tool, saved as fixtures.
5. What happens at the hook's timeout, and what the largest accepted `timeout` is.
6. How `SessionStart` reports resume and clear, so one pane thread can follow a session
   whose id changes.
7. How long `stratta hook` takes to start on that machine.

Outcome: either "go, with these adjustments" or "the hold blocks the pane; ship local
first and policy only".

### Phase 1: requests only (medium)

The smallest thing worth using.

- Core: `Stratta.PaneThread`; `pane.register` and `hook.permission` operations; thread
  `kind`; approval items built from a tool name and input (a diff for edits and new
  files, the command line for shell commands).
- Client: `stratta run`, `stratta hook permission-request`, the launcher script, the
  Claude Code translator.
- Coarse status from the one hook: waiting while a request is held, otherwise unknown.
- Tests: a scripted stand-in for the agent that runs the configured hook commands the way
  the real one does, in the style of the existing demo agent. It covers approve, deny,
  timeout falling through, a stale name refused, and two requests at once.

Done when a request raised in a real Claude Code pane shows as `Na` in `stratta watch`
and can be approved from another pane.

### Phase 2: the rest of the thread (medium)

- `SessionStart`, `UserPromptSubmit`, `Stop` and `SessionEnd` hooks: user messages, the
  last reply of each turn, working and idle status, and ending the thread when the agent
  exits.
- `stratta run --worktree`: make the branch and worktree first, then start the agent in it.
- Diff, commit, push and ship for pane threads (they should need no change; verify).
- The viewer and the app show a pane thread read-only, with a note that the conversation
  is in its pane.

### Phase 3: policy (medium)

Answer some requests without asking anyone.

- Rules per thread or project: for example allow reads and searches, ask for shell
  commands, deny anything outside the working folder.
- "Always allow this" from Stratta, passed back to the agent as `updatedPermissions`.
- The hold choice from the open question above, as a setting.
- This is the natural place for the Jido Agent integration listed in the README: rules as
  Jido actions rather than a bespoke matcher.

### Phase 4: reaching into the pane (small to medium, optional)

Hooks cannot type into the agent. To send or stop from Stratta, a pane thread needs the
terminal's help, so this goes through a hook of the same kind as `STRATTA_OPENER`:
`STRATTA_SENDER`, a command of yours that delivers text to a thread's pane. Where no
sender is set, `stratta send` to a pane thread explains that the thread is typed into
directly.

Hand-off from a pane thread can use the transcript file the hooks name.

### Later

Other agents, one translator each, where they offer an equivalent permission hook.

## Safety

- **The decision channel is the control socket**, which only its owner can open. A pane
  thread adds no network listener.
- **An agent must not be able to answer its own requests.** Any process running as you can
  reach the socket, and that includes commands an agent runs. A shell command that an
  agent is already allowed to run could call `stratta approve` for a different pending
  request. This gap exists today for headless threads too and is worth closing in Phase 1
  for both kinds:
  - the daemon checks who is calling (the operating system can report the process on the
    other end of a Unix socket) and refuses `thread.approve` from any process descended from an agent it started or
    registered;
  - agents are started with a marker in their environment that makes the `stratta` client
    refuse to approve, as a second, softer line.
- **A hook that fails must not approve.** Any error or timeout in `stratta hook` produces
  "no decision", never "allow".
- **Your settings files are not touched.** Hooks are added for the run and are gone when
  the agent exits. *verify in Phase 0*

## Not in scope

- Reading the agent's screen to guess its state.
- Replacing headless threads.
- Keeping a pane thread alive after its terminal closes.

## Findings

*To be filled in by Phase 0.*
