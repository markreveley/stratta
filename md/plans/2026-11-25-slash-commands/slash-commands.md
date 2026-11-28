---
type: plan
kind: need
---

# Slash commands: list them, suggest them, send them

> Status: proposed · 2026-11-27

## Summary

Agents running in protocol mode advertise slash commands, and a command is run by sending
its text as an ordinary message. Stratta already passes messages through unchanged, so
`stratta send "/name arguments"` reaches the agent as a command today. What is missing is
knowing which commands exist: the agent's list arrives and Stratta drops it.

This plan keeps that list and shows it in three places: a `stratta commands` listing, the
terminal viewer's composer, and the app's composer. It is small and mostly independent of
everything else.

It applies to headless threads only. In a pane thread (see
[`pane-threads-via-hooks.md`](../2026-11-25-pane-threads-via-hooks/pane-threads-via-hooks.md)) you type commands into the
agent's own interface.

## Why this exists

Kind: **need**, small.

A fact in the code: an agent's list of commands arrives and Stratta drops it.

## What happens today

Checked in the code on 2026-11-25:

- The protocol (<https://agentclientprotocol.com/protocol/slash-commands>): after a
  session starts, an agent may send an `available_commands_update` with a list of
  commands, each with a `name`, a `description` and an optional input `hint`. It may send
  a new list at any time. A command is run by sending a normal prompt whose text starts
  with `/name`.
- `Jido.Harness` speaks protocol version 1 and does not interpret this update. It passes
  it on as a provider event of kind `acp_update` with the raw update inside
  (`session/transports/acp.ex`, `map_update/1`).
- `Stratta.Timeline` handles `acp_update` only to read the current model, so the command
  list is discarded.
- `Stratta.ThreadServer` sends message text to the session as it is, so a message that
  starts with `/` is already delivered as a command.
- The bundled demo agent advertises no commands, so none of this is exercised by a test.

## Design

- **The list belongs to the session, not the transcript.** `Stratta.Timeline` keeps the
  latest list in a `commands` field, replaced whole on every update, and it goes out in
  the snapshot beside the items. It is not a timeline item and is not written to the
  thread's file.
- **A thread that is not running has no list.** Sessions start lazily, on the first
  message, so a new thread knows no commands yet. Asking for the list is a reason to start
  the session: `stratta commands` and the first `/` typed in a composer start it without
  sending anything. Starting a session launches the agent's process, which is why it only
  happens on those explicit actions.
- **No validation.** Stratta suggests commands; it does not police them. Text that starts
  with `/` is sent whether or not it is in the list, because an agent may accept commands
  it did not advertise, and a message may simply begin with a path.
- **A command is a message.** It queues behind a running turn, can be steered in, and
  shows in the timeline as the user message it is. Nothing about turns changes.
- **Not in the thread list.** The list of threads that the dashboard and sidebar
  subscribe to does not carry commands; only a thread's own snapshot does.

## Work

### Phase 1: core, command line, demo agent (small)

- `Stratta.Timeline`: a `commands` field, set from `available_commands_update`.
- `Stratta.ThreadServer`: `commands` in the snapshot; a way to start the session without
  sending (`ensure_session` is already separate from sending).
- `Stratta.API`: `thread.commands`, which starts the session if needed and returns the
  list.
- Client: `stratta commands [THREAD] [--json]`, printing each command with its hint and
  description. Listed in `stratta help`.
- Demo agent: advertise two commands and act on them, so the path is tested end to end.
  For example `/files` (list the working folder, no plan, no edit) and `/note TEXT`
  (request an edit that appends TEXT).
- Tests: the timeline keeps and replaces the list; the socket returns it; `stratta
  commands` prints it; sending `/files` produces the demo agent's command behaviour
  rather than its usual turn.

Done when `stratta commands` lists the demo agent's commands and `stratta send "/files"`
runs one.

### Phase 2: the terminal viewer (small)

- While the composer's text starts with `/` and has no space yet, the status line shows
  the matching commands and the first match's description.
- Tab completes to the first match; Tab again moves to the next.
- Tests on the pure render and key functions, as for the rest of the viewer.

### Phase 3: the app (small)

- The composer shows a short list of matching commands under the cursor while its text
  starts with `/`. Click, or Tab, inserts the command and a space.
- The list is sent to the page with the snapshot and filtered in the browser, so typing
  stays instant.
- The side-by-side guide (`md/docs/app-and-terminal.md`) gets a row for it.

### Phase 4: check against real agents (small; needs a machine with agents installed)

Things only a real agent can answer, to be recorded here:

- Which commands each agent advertises in protocol mode, and how that differs from its
  interactive interface. Commands that open a picker or a dialog are usually left out.
- Whether a command's output arrives as ordinary reply text, and whether a command that
  takes no model turn still ends the turn cleanly.
- Whether any agent sends its list with session setup rather than as an update. Protocol
  version 2 allows that; Harness speaks version 1 today.
- Whether any agent needs a command to be the whole message, with nothing after it.

## Not in scope

- Defining Stratta's own slash commands.
- Running an agent's interactive-only commands. Those need its interface; that is what
  pane threads are for.
- Remembering a thread's commands while its session is stopped. If starting the session
  on demand turns out to be too slow, cache the last known list with the thread.

## Findings

*To be filled in by Phase 4.*
