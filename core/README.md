# Stratta core

The daemon. It owns the agent sessions and everything about a thread; front ends only
show it and send it commands.

```sh
mix setup
mix run --no-halt      # headless daemon
mix test
```

## Modules

| module | role |
| --- | --- |
| `Stratta.ThreadServer` | One GenServer per thread. Owns a `Jido.Harness.Session`, follows its event stream, persists the timeline, broadcasts snapshots on PubSub. Sessions start lazily, on the first message. |
| `Stratta.Timeline` | Pure reducer from Harness events to chat items (messages, thinking, plans, tool calls, approvals, turn ends). |
| `Stratta.Threads` | Projects and threads: create (with optional worktree), hand off, delete, diff, commit, push, ship. |
| `Stratta.Git` | Worktrees, diff parsing, commit, push, `gh pr create`. |
| `Stratta.Providers` | The Harness provider catalogue with cached readiness, and which session options each provider accepts. |
| `Stratta.Store` | JSON files under the data directory: `state.json` and `threads/<id>.json`, written atomically. |
| `Stratta.API` | Named operations with JSON-shaped arguments and results. |
| `Stratta.Socket` | Serves `Stratta.API` on a Unix socket, plus live subscriptions. |
| `Stratta.DemoAdapter` | A custom `Jido.Harness.Adapter` for the scripted demo agent in `priv/demo_agent/`. |

Harness does the hard part: process lifetime, ACP framing, queued follow-ups, approvals,
steering and bounded replay all come from `Jido.Harness.Session`. The core is a projection
of its events plus git plumbing.

## Configuration

None is required.

| setting | default | meaning |
| --- | --- | --- |
| `STRATTA_DATA_DIR` or `config :stratta, data_dir:` | `~/.stratta` | projects, threads, transcripts, socket |
| `STRATTA_SOCKET` | `<data dir>/stratta.sock` | control socket path |
| `config :stratta, socket: false` | `true` | do not serve the socket |
| `config :stratta, worktree_dir:` | `.stratta/worktrees` | where thread worktrees go, inside each project |

One daemon per data directory: a second one refuses to start rather than share the files.

## The control socket

JSON objects, each prefixed with its length as a 4-byte big-endian integer.

```
→ {"id": 1, "op": "thread.send", "args": {"thread": "tAb3", "text": "hi"}}
← {"id": 1, "ok": true, "result": {"how": "sent"}}
← {"id": 1, "ok": false, "error": "No thread matches \"tAb3\"."}
```

A thread is addressed by its id or any unique prefix of it.

| operation | arguments |
| --- | --- |
| `ping` | |
| `projects.list`, `projects.add` | `path` |
| `providers.list` | `refresh` |
| `threads.list` | |
| `threads.create` | `project` (id, name or path), `provider`, `worktree`, `model`, `approval_mode`, `sandbox_mode`, `message` |
| `thread.get` | `thread` |
| `thread.send` | `thread`, `text`, `mode` (`auto` or `steer`) |
| `thread.interrupt` | `thread` |
| `thread.approve` | `thread`, `decision` (`approve` or `deny`), `request_id` (default: the oldest pending) |
| `thread.set_model` | `thread`, `model` |
| `thread.diff` | `thread` |
| `thread.commit` | `thread`, `message` |
| `thread.push` | `thread` |
| `thread.draft_pr`, `thread.ship` | `thread`, `title`, `body`, `draft` |
| `thread.handoff` | `thread`, `provider` |
| `thread.delete` | `thread` |
| `subscribe` | `thread`: replies with a snapshot, then pushes `{"event": "thread", "thread": id, "snapshot": …}` on every change |
| `subscribe` | `all: true`: replies with the thread list, then pushes `{"event": "threads", "threads": […]}` |

Pushes are coalesced, so a burst of changes sends only the latest state.

## Adding a provider

A `Jido.Harness.Adapter` module (see `Stratta.DemoAdapter`) and one entry in
`config :jido_harness, providers: %{name: Module}`.
