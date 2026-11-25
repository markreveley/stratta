# The app and the terminal, side by side

Stratta has two front ends over one daemon: the **app** (the LiveView GUI in a browser)
and the **terminal** (the `stratta` command and its live viewer). They show the same
threads, and a change made in one appears in the other as it happens. This guide maps
each thing you can do onto both.

In the terminal column, `ID` is a thread id from `stratta ls`. Any unique prefix of it
works, and where the help shows `[THREAD]` you can leave it out if there is only one
thread or `$STRATTA_THREAD` is set.

- [Start here](#start-here)
- [A first thread, both ways](#a-first-thread-both-ways)
- [Set up](#set-up)
- [Start and find threads](#start-and-find-threads)
- [Talk to the agent](#talk-to-the-agent)
- [Approvals](#approvals)
- [Read the work](#read-the-work)
- [Change a thread](#change-a-thread)
- [Review and ship](#review-and-ship)
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
| 4. Approve the edit | A card shows the proposed change. Press **Approve**. | The status line shows `y approve  n deny`. Press `y`. |
| 5. Review the change | Press **Diff** in the thread header. | Press ctrl-d to leave the viewer, then `stratta diff` |
| 6. Commit it | In the diff panel, edit the message and press **Commit**. | `stratta commit -m "Add notes file"` |
| 7. Follow up | Type in the composer and press Enter. | `stratta attach`, type, press Enter. Or `stratta send ID "now add a heading"` |

Steps 5 to 7 in the terminal leave the thread id out, which works while there is only one
thread. If you tried the app column first you now have two, so pass the id that
`stratta ls` shows, for example `stratta diff ID`.

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
| See every thread and its state | The sidebar. The dot pulses purple while working and amber while waiting for approval; red is failed; grey is idle or not started. | `stratta ls` for a snapshot, `stratta watch` for a live list |
| Open a thread | Click it in the sidebar. | `stratta attach ID`, or press Enter on it in `stratta watch` |
| Check one thread without opening it | Hover and read the sidebar dot. | `stratta status ID` |

The model, approval and sandbox fields appear in the app only for agents that accept
them. The terminal accepts the options for any agent and leaves out the ones that agent
does not take.

## Talk to the agent

"Viewer" means `stratta attach`. The commands in the last column work from any shell,
with no viewer open, which is what makes them useful in scripts and key bindings.

| To | In the app | In the viewer | As a command |
| --- | --- | --- | --- |
| Send a message | Type in the composer, press Enter or **Send**. | Type, press Enter. | `stratta send ID TEXT` |
| Write several lines | Shift+Enter adds a line. | Paste them. Line breaks show as `⏎`. | Quote the text with its line breaks. |
| Queue a follow-up while a turn runs | Enter or **Queue**. It runs when the current turn ends. | Enter | `stratta send ID TEXT` prints "Queued behind the running turn." |
| Steer the running turn | **Steer**, or Cmd/Ctrl+Enter | alt-enter or ctrl-s | `stratta send --steer ID TEXT` |
| Stop the running turn | **■ Stop** | esc | `stratta stop ID` |

Steering puts your message into the turn that is already running, where queueing waits
for it to finish. Not every agent can be steered. The app shows **Steer** only for those
that can; the terminal queues the message instead.

## Approvals

When an agent asks permission, for an edit or a command, the thread waits.

| To | In the app | In the viewer | As a command |
| --- | --- | --- | --- |
| Notice a request | The thread's sidebar dot pulses amber. | The status line turns into the request. The terminal is told too; see below. | `stratta ls` shows `needs approval`; `stratta watch` counts them in its header. |
| See what is being asked | The request card shows the proposed change. | The change is shown in the timeline above the status line. | `stratta status ID` names the request. |
| Approve | **Approve** on the card | `y`, with the composer empty | `stratta approve ID` |
| Deny | **Deny** on the card | `n`, with the composer empty | `stratta deny ID` |

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
| Get everything, unabridged | Expand the rows. | `stratta status ID --json` returns the whole thread, every item in full. |
| See context use | On the line that ends each turn | The same line |

The viewer is deliberately brief. When you need the full text of a long tool result, use
the app or the JSON output.

## Change a thread

| To | In the app | In the terminal |
| --- | --- | --- |
| Switch model mid-thread | Type the name into the model box in the thread header and press Enter. Shown for agents that allow it. | `stratta model ID NAME` |
| Hand off to another agent | **Hand off…** in the thread header. A new thread opens in the same working folder, seeded with the conversation. | `stratta handoff ID AGENT` prints the new thread's id. |
| Delete a thread | **🗑** in the thread header. It asks first. Its worktree is removed too. | `stratta rm ID`. It does not ask. |

## Review and ship

| To | In the app | In the terminal |
| --- | --- | --- |
| See what changed | **Diff** in the thread header opens the changes against the commit the thread started from, including new files. | `stratta diff ID` |
| Keep the diff open while the agent works | Leave the panel open. It reloads when a turn ends; **↻** reloads it now. | `stratta diff ID --watch` reloads after each tool call and turn. `r` reloads now, `q` quits. |
| Commit | Diff panel: edit the message, **Commit** | `stratta commit ID -m "message"` |
| Commit with the default message | Leave the message as it is: the thread's title. | Leave out `-m`. |
| Push the branch | **Push** in the diff panel | `stratta push ID` |
| Open a pull request | **Ship**: review the drafted title and body, tick **Open as draft** if you want, then **Commit, push & open PR** | `stratta ship ID`, with `--title`, `--body` and `--draft` as needed |
| Find the pull request later | **PR ↗** in the thread header | `stratta status ID` |

Shipping commits anything uncommitted, pushes, and opens the pull request in one step. It
needs a git remote and a signed-in `gh`. The app lets you read and edit the drafted
description first. The terminal uses the draft as it is unless you pass your own
`--title` and `--body`.

## Only in one of them

**Only in the app**

- The install plan for an agent, and removing a project.
- Full tool input and output, and rendered formatting in replies.
- Editing the drafted pull request description before shipping.

**Only in the terminal**

- **Detach and come back.** ctrl-d leaves the viewer and the agent keeps working.
  `stratta attach ID` picks it up again, from any terminal on the machine.
- **Scripting.** Every command is one-shot and most take `--json`. Exit status is 0 for
  success, 1 when the daemon refuses, 2 for bad usage, 4 when no daemon is running.
- **Status on the terminal itself.** A viewer tells its terminal whether the agent is
  working, waiting on you, finished or failed, so a tab or session list can show it while
  you look elsewhere. `STRATTA_STATUS_HOOK` runs a command of yours on each change, for a
  notification or a status line. `stratta attach --bell` rings when a request starts
  waiting.
- **Your own layout.** `stratta open ID` runs `$STRATTA_OPENER`, a script of yours that
  asks your terminal for the windows and splits you like, for example a viewer beside
  `stratta diff --watch`.

The [terminal client's README](../tui/README.md) covers the last two in detail.

## Using both at once

Nothing needs switching on. Both front ends are views of the same daemon, so:

- A thread started with `stratta new` appears in the app's sidebar at once.
- A message sent from the app shows up in an attached viewer, and the other way round.
- Either side can answer an approval. The other side sees it resolved.
- Several viewers, and several browser tabs, can watch one thread.

A split that works well: start and steer threads from the terminal while you are already
there, let the terminal's own status tell you when one needs you, and use the app when it
is time to read a long diff or write a pull request description.
