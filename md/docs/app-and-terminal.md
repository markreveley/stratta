# The app and the terminal, side by side

Stratta has two front ends over one daemon: the **app** (the LiveView GUI in a browser)
and the **terminal** (the `stratta` command and its live viewer). They show the same
threads, and a change made in one appears in the other as it happens. This guide maps
each thing you can do onto both.

In the terminal column, `N` is a thread's slot number: the `#` column of `stratta ls`,
and the number beside the thread in the app. Leave it out and a command acts on the
current thread, the one you last started with `stratta new` or chose with `stratta use N`.
A permission request is named by slot and letter, such as `2a`.

- [Start here](#start-here)
- [A first thread, both ways](#a-first-thread-both-ways)
- [Set up](#set-up)
- [Start and find threads](#start-and-find-threads)
- [Talk to the agent](#talk-to-the-agent)
- [Approvals](#approvals)
- [Read the work](#read-the-work)
- [Change a thread](#change-a-thread)
- [Review and ship](#review-and-ship)
- [Slots and the current thread](#slots-and-the-current-thread)
- [Two panes: commands on the left, dashboard on the right](#two-panes-commands-on-the-left-dashboard-on-the-right)
- [Only in one of them](#only-in-one-of-them)
- [Using both at once](#using-both-at-once)

## Start here

Something has to own the agents before either front end is useful. That is the daemon,
and there are two ways to run it. Pick one; a second daemon on the same data refuses to
start.

| | command | gives you |
| --- | --- | --- |
| With the app | `cd gui && mix setup && mix phx.server` | the daemon and the app at <http://localhost:4001> |
| Without the app | `cd core && mix setup && mix run --no-halt` | the daemon only |

The terminal client works against either one:

```sh
cd tui && mix setup      # builds ./stratta; put it on your PATH
stratta agents           # answers if a daemon is running
```

## A first thread, both ways

The demo agent is a scripted stand-in that needs no install or account. Ask it to *edit*
or *create* something and it will request permission, write a file and summarize. Try the
whole loop once in each front end, in any git repository.

| step | In the app | In the terminal |
| --- | --- | --- |
| 1. Add the project | Paste the repository's path into **Add project** at the bottom of the sidebar and press Enter. | `cd` into the repository. The next step adds it for you. |
| 2. Start a thread | **+ New thread**. Choose the project, leave the agent on **Stratta Demo Agent**, type `create a notes file`, press **Start thread**. | `stratta new --attach "create a notes file"` |
| 3. Watch it work | The thread opens. Thinking, a plan and tool calls stream in. | The viewer opens with the same stream. |
| 4. Approve the edit | A card shows the proposed change. Press **Approve**. | The status line shows the request, `1a`, and `y approve  n deny`. Press `y`. |
| 5. Review the change | Press **Diff** in the thread header. | Press ctrl-d to leave the viewer, then `stratta diff` |
| 6. Commit it | In the diff panel, edit the message and press **Commit**. | `stratta commit -m "Add notes file"` |
| 7. Follow up | Type in the composer and press Enter. | `stratta attach`, type, press Enter. Or `stratta send "now add a heading"` |

Steps 5 to 7 in the terminal name no thread. They act on the current thread, which
`stratta new` set in step 2.

## Set up

| To | In the app | In the terminal |
| --- | --- | --- |
| See which agents are ready | **⚙** at the top of the sidebar opens the agents page: installed, signed in, ready. | `stratta agents` |
| Re-check after installing or signing in | **↻ Re-check** on the agents page | `stratta agents --refresh` |
| See how to install an agent | **install plan** next to it on the agents page | Not available. Use the app, or `Jido.Harness.install/2` in `iex`. |
| Add a project | Paste its path into **Add project** in the sidebar. | `stratta project add PATH`, or just run `stratta new` inside it. |
| List projects | The sidebar | `stratta projects` |
| Remove a project | Hover its name in the sidebar and press **×**. Files are not deleted. | Not available. |

## Start and find threads

| To | In the app | In the terminal |
| --- | --- | --- |
| Start a thread | **+ New thread**, fill in the form, **Start thread** | `stratta new "what to do"` from inside the project |
| Choose the project | **Project** menu | `-p PATH` or `-p NAME`. Default: the current folder. |
| Choose the agent | **Agent** menu, which also shows whether each is ready | `-a NAME`, with names from `stratta agents`. Default: `demo`. |
| Choose a model | **Model** box. Blank means the agent's default. | `--model NAME` |
| Set approval and sandbox modes | **Approvals** and **Sandbox** menus | `--approval MODE` and `--sandbox MODE` |
| Give it its own branch and worktree | **Isolate in a new branch + git worktree**, on by default | On by default. `--no-worktree` works in the project folder itself. |
| Start without a first message | Leave the task box empty. | `stratta new` with no text |
| See a thread's number | Beside its title in the sidebar and the thread header | The `#` column of `stratta ls` |
| See every thread and its state | The sidebar. The dot pulses purple while working and amber while waiting for approval; red is failed; grey is idle or not started. | `stratta ls` for a snapshot, `stratta watch` for the live dashboard |
| Open a thread | Click it in the sidebar. | `stratta attach N`, or select it in `stratta watch` and press Enter |
| Check one thread without opening it | Hover and read the sidebar dot. | `stratta status N` |

The model, approval and sandbox fields appear in the app only for agents that accept
them. The terminal accepts the options for any agent and leaves out the ones that agent
does not take.

## Talk to the agent

"Viewer" means `stratta attach`. The commands in the last column work from any shell,
with no viewer open, which is what makes them useful in scripts and key bindings. Each
takes a slot number first, or none for the current thread: `stratta send "more tests"`.

| To | In the app | In the viewer | As a command |
| --- | --- | --- | --- |
| Send a message | Type in the composer, press Enter or **Send**. | Type, press Enter. | `stratta send N TEXT` |
| Write several lines | Shift+Enter adds a line. | Paste them. Line breaks show as `⏎`. | Quote the text with its line breaks. |
| Queue a follow-up while a turn runs | Enter or **Queue**. It runs when the current turn ends. | Enter | `stratta send N TEXT` prints "Queued behind the running turn." |
| Steer the running turn | **Steer**, or Cmd/Ctrl+Enter | alt-enter or ctrl-s | `stratta send --steer N TEXT` |
| Stop the running turn | **■ Stop** | esc | `stratta stop N` |

Steering puts your message into the turn that is already running, where queueing waits
for it to finish. Not every agent can be steered. The app shows **Steer** only for those
that can; the terminal queues the message instead.

## Approvals

When an agent asks permission, for an edit or a command, the thread waits.

| To | In the app | In the viewer | As a command |
| --- | --- | --- | --- |
| Notice a request | The thread's sidebar dot pulses amber. | The status line turns into the request. The terminal is told too; see below. | `stratta watch` lists every waiting request under **Waiting on you**; `stratta ls` shows them beside the status. |
| See what is being asked | The request card shows its name and the proposed change. | The change is shown in the timeline above the status line. | `stratta watch` shows it for the current thread; `stratta status N` names it. |
| Approve | **Approve** on the card | `y`, with the composer empty | `stratta approve 2a` |
| Deny | **Deny** on the card | `n`, with the composer empty | `stratta deny 2a` |

A request's name is its thread's slot and a letter: `2a` is the first request of the
thread in slot 2, `2b` its next. Letters are never reused within a thread, so a name
always means the same request. If `2a` has been answered, `stratta approve 2a` says so and
does nothing; it will not fall through to a newer request you have not read. With no
name, `stratta approve` answers the current thread's request when exactly one is waiting.

In the viewer, `y` and `n` only answer a request while the composer is empty, so you can
still type words that start with them.

## Read the work

| To | In the app | In the terminal |
| --- | --- | --- |
| Follow the reply as it streams | The timeline, which stays pinned to the bottom until you scroll up | The viewer does the same. |
| Scroll back | Scroll the timeline. | pgup, pgdn, ↑, ↓ in the viewer. End follows the latest output again. |
| Read the agent's thinking | Open **Thinking**. | The viewer shows its first two lines. |
| See the plan | The plan list, ticked off as steps finish | The same list |
| Inspect a tool call | Click its row for the full input, output and change. | The viewer shows the title, the first lines of output and the first lines of a change. |
| Get everything, unabridged | Expand the rows. | `stratta status N --json` returns the whole thread, every item in full. |
| See context use | On the line that ends each turn | The same line |

The viewer is deliberately brief. When you need the full text of a long tool result, use
the app or the JSON output.

## Change a thread

| To | In the app | In the terminal |
| --- | --- | --- |
| Switch model mid-thread | Type the name into the model box in the thread header and press Enter. Shown for agents that allow it. | `stratta model N NAME` |
| Hand off to another agent | **Hand off…** in the thread header. A new thread opens in the same working folder, seeded with the conversation. | `stratta handoff N AGENT` prints the new thread's number and makes it current. |
| Delete a thread | **🗑** in the thread header. It asks first. Its worktree is removed too. | `stratta rm N`. It does not ask. |

## Review and ship

| To | In the app | In the terminal |
| --- | --- | --- |
| See what changed | **Diff** in the thread header opens the changes against the commit the thread started from, including new files. | `stratta diff N` |
| Keep the diff open while the agent works | Leave the panel open. It reloads when a turn ends; **↻** reloads it now. | `stratta diff N --watch` reloads after each tool call and turn. `r` reloads now, `q` quits. |
| Commit | Diff panel: edit the message, **Commit** | `stratta commit N -m "message"` |
| Commit with the default message | Leave the message as it is: the thread's title. | Leave out `-m`. |
| Push the branch | **Push** in the diff panel | `stratta push N` |
| Open a pull request | **Ship**: review the drafted title and body, tick **Open as draft** if you want, then **Commit, push & open PR** | `stratta ship N`, with `--title`, `--body` and `--draft` as needed |
| Find the pull request later | **PR ↗** in the thread header | `stratta status N` |

Shipping commits anything uncommitted, pushes, and opens the pull request in one step. It
needs a git remote and a signed-in `gh`. The app lets you read and edit the drafted
description first. The terminal uses the draft as it is unless you pass your own
`--title` and `--body`.

## Slots and the current thread

Thread ids are long, so each thread sits in a numbered slot and is called by that number
everywhere. A new thread takes the lowest free slot. Slots never shift on their own: one
changes hands only when you delete, unslot or move its thread.

| To | In the app | In the terminal |
| --- | --- | --- |
| Choose the thread your commands act on | Click it. Each browser tab shows the thread you opened in it. | `stratta use N`. `stratta new` and `stratta handoff` also switch to the thread they create. |
| See which thread is current | The highlighted one in the sidebar, for that tab | `stratta use`, or the `*` in `stratta ls` |
| Act on another thread just once | Open it. | Name it: `stratta diff 3`, `stratta send 3 "…"` |
| Move a thread to a slot | Not available. | `stratta slot N 5`. A thread already in slot 5 takes the slot this one leaves. |
| Free a slot without deleting the thread | Not available. | `stratta unslot N`. The thread stays and answers to its id. |

The current thread is shared by every shell and dashboard in the same workspace, which is
what lets one pane follow another. Set `STRATTA_WORKSPACE` to a name of your own in a
second terminal setup to give it a separate current thread. The app does not use the
current thread: clicking a thread there does not move it, and `stratta use` does not
change what a browser tab shows.

`stratta send` reads a leading number as a slot. To send text that starts with a number
to the current thread, name the thread with `-t`: `stratta send -t 1 "2 more tests"`.

## Two panes: commands on the left, dashboard on the right

Split your terminal. Run `stratta watch` on the right and leave it. Work from the shell
on the left.

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

The top lists every slotted thread and every request waiting on you. The bottom follows
the current thread. From the left pane:

| On the left | On the right |
| --- | --- |
| `stratta new "create a notes file"` | A new row appears and the bottom switches to it. |
| `stratta use 2` | The bottom switches to thread 2. |
| `stratta send "also add a heading"` | The message and the agent's work stream into the bottom. |
| `stratta approve 1a` | `1a` leaves **Waiting on you** and thread 1 carries on. |
| `stratta commit -m "…"`, `stratta ship` | A notice with the result appears in the thread. |

It works the other way too: in the dashboard, ↑, ↓ or a digit selects a thread, which
makes it the current thread for the left pane's commands. Enter opens the selected
thread in the full viewer.

## Only in one of them

**Only in the app**

- The install plan for an agent, and removing a project.
- Full tool input and output, and rendered formatting in replies.
- Editing the drafted pull request description before shipping.

**Only in the terminal**

- **Detach and come back.** ctrl-d leaves the viewer and the agent keeps working.
  `stratta attach N` picks it up again, from any terminal on the machine.
- **Scripting.** Every command is one-shot and most take `--json`. Exit status is 0 for
  success, 1 when the daemon refuses, 2 for bad usage, 4 when no daemon is running.
- **Status on the terminal itself.** A viewer tells its terminal whether the agent is
  working, waiting on you, finished or failed, so a tab or session list can show it while
  you look elsewhere. `STRATTA_STATUS_HOOK` runs a command of yours on each change, for a
  notification or a status line. `stratta attach --bell` rings when a request starts
  waiting.
- **Slots you arrange.** `stratta slot` and `stratta unslot` decide which thread answers
  to which number.
- **A dashboard beside your shell.** `stratta watch` follows the thread your commands are
  acting on.
- **Your own layout.** `stratta open N` runs `$STRATTA_OPENER`, a script of yours that
  asks your terminal for the windows and splits you like, for example a viewer beside
  `stratta diff --watch`.

The [terminal client's README](../../tui/README.md) covers the last two in detail.

## Using both at once

Nothing needs switching on. Both front ends are views of the same daemon, so:

- A thread started with `stratta new` appears in the app's sidebar at once.
- A message sent from the app shows up in an attached viewer, and the other way round.
- Either side can answer an approval. The other side sees it resolved.
- Several viewers, and several browser tabs, can watch one thread.

A split that works well: start and steer threads from the terminal while you are already
there, let the terminal's own status tell you when one needs you, and use the app when it
is time to read a long diff or write a pull request description.
