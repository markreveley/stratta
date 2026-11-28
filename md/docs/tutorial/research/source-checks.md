# Source checks

What each claim in the tutorial rests on. "Read" means the file was read in a clone at the commit
named. "Run" means executed here, with the transcript under `verify/`. "Tool" means read through a
retrieval tool that returns a model's answer about a page. "Training" means general background not
checked against a document while writing.

## Checkouts

| Repository | Commit | Date | Version |
|---|---|---|---|
| `markreveley/stratta` | `a7c451f` | 2026-11-25 | core 0.2.0 |
| `agentjido/jido` | `14424fe` | 2026-11-24 | 3.0.0-beta.3 |
| `agentjido/jido_harness` | `f810a4c` | 2026-11-25 | 3.0.0-rc.1 |
| `happi/theBeamBook` | `b7ba61b` | 2026-09-25 | |
| `phoenixframework/phoenix_pubsub` | `79d97f0` | | |
| `markreveley/stratta`, `main` | `2846650` | 2026-11-27 | plans, `next.md`, `state.md`, and the repair to item ids in `timeline.ex` |
| `markreveley/stratta`, `main` | `f102429` | 2026-11-26 | the commit before that repair; `timeline.ex` as at `a7c451f` |
| `ash-project/reactor` | `7b4134c` | 2026-11-26 | 1.0.8 |
| `zblanco/runic` | `0c15a9c` | 2026-10-27 | 0.1.0-alpha.13 |
| `markmark206/journey` | `fe8e90d` | 2026-11-25 | 0.11.1 |

## Stratta, today

| Section | Claim | Source | How |
|---|---|---|---|
| 1, 2 | What Stratta is; three projects; the app runs the core in its node; the client uses the socket | `README.md`, `core/README.md`, `gui/mix.exs`, `gui/lib/stratta_web/application.ex` | Read |
| 3 | The nine steps of a permission request | `thread_server.ex`, `timeline.ex`, `api.ex`, `socket.ex` | Read |
| 6 | Events arrive in `handle_info`; stale sessions ignored; save debounced at 400 ms | `thread_server.ex` | Read; excerpt checked |
| 6 | Store serialises changes and writes by rename | `store.ex` | Read |
| 7 | Only `Stratta.Socket` traps exits | `grep -rn trap_exit core/lib gui/lib tui/lib` | Run: one match, `socket.ex:52` |
| 8 | The six children and their order | `application.ex` | Read; excerpt checked |
| 9 | `via`, `ensure_started`, `restart: :transient`, `summary/1` without starting | `thread_server.ex` | Read; excerpt checked |
| 9 | A reloaded thread marks waiting requests expired | `timeline.ex`, `close_dangling/1` | Read |
| 10 | Follower task; a task per connection and per request; `Task.async_stream`, six at a time, one-minute cache | `thread_server.ex`, `socket.ex`, `providers.ex` | Read |
| 11 | Item kinds; label function; pending requests expire at turn end; ids and times from the system | `timeline.ex` | Read; excerpt checked |
| 12 | `state.json` and one file per thread; no event log kept | `store.ex` | Read |
| 12, 40 | Before the repair, item ids came from a counter of the virtual machine; a reloaded timeline restored the next request letter and not the next id; an update changes every item with a matching id | `timeline.ex` at `f102429`: `push_with_id/2`, `new/1`, `update_item/3` | Read |
| 12, 40 | Before the repair, a new item after a restart repeated an id and a tool's result was written into both items | `scripts/check_timeline_ids.sh` against `timeline.ex` alone at `f102429`, with a stand-in for the event struct | Run: `verify/timeline-ids-before.txt` (Elixir 1.14.0, OTP 25) |
| 12 | After the repair, ids are counted per timeline and carried on from the stored items; the same check reports no repeated id | `timeline.ex` at `2846650`: `number_items/1`, `push_with_id/2`; the same script | Read; Run: `verify/timeline-ids.txt` (Elixir 1.14.0, OTP 25) |
| 13 | Three topics and their messages; the list is told only on a changed triple | `thread_server.ex`, `threads.ex`, `socket.ex` | Read; excerpt checked |
| 13 | Phoenix.PubSub registers subscribers in a Registry | `phoenix_pubsub/lib/phoenix/pubsub.ex` | Read |
| 14 | Whole snapshots; 40 ms coalescing | `socket.ex` | Read; excerpt checked |
| 15 | Listening options, mode 0600, stale-socket check, `active: :once` | `socket.ex` | Read; excerpt checked |
| 16 | Twenty-one operations; `call/2` never raises; `2a` handling | `api.ex` | Read; excerpt checked; operations counted |
| 20 | Raw mode, alternate screen, the view contract, the loop | `tui/.../term.ex` (opening), `app.ex` | Read |
| 20 | `Render` measures one cell per character; `Keys` behaviour | the hyperlinks and composer plans | Plans' own code check, not re-read |
| 33 | Hand-off seeds the last 20 messages, 2,000 characters each | `threads.ex`, `handoff/2` | Read |
| 34 | A hand-off writes `handoff_from` on the new thread; no parent link exists | `threads.ex`, `handoff/2` | Read |
| 40 | Deleting a thread stops its process through the supervisor | `threads.ex`, `delete_thread/1` | Read |

## Stratta, planned

Everything in Part 6, section 19, and the planned rows of section 21 is from the plan named in the
text, read in full at `a7c451f`. Quotations are exact. Section 37's "Needs" column is from the
sentences of `next.md` that say what each step needs.

Sections 25 and 34, the end of section 12 and the last two items of section 40 follow
`md/plans/2026-11-26-event-log/event-log.md`, `md/plans/2026-11-26-graphs/graphs.md` and the sentences added with them to seven plans and to
`next.md`, at `2846650` on Stratta's `main`. Those plans, and the repair to item ids, were written in
the same session as the sections that describe them.

## References

| Section | Claim | Source | How |
|---|---|---|---|
| 5 | A process is four blocks of memory; sending copies | BEAM Book, *Processes* | Read |
| 5 | Scheduling by reductions; a budget of a few thousand | BEAM Book, *Scheduling*, "Reductions" (4,000 as the book states it) | Read |
| 17 | A port is the process-like interface to what is not Erlang; an external program cannot crash the node; native code can | BEAM Book, *IO, Ports and Networking*; *Interfacing Other Languages* | Read |
| 17 | Harness builds a native helper from C++; it manages process groups; it has a `pty` option | Harness `README.md`, `guides/overview.md`, `process/spec.ex` | Read |
| 10, 22 | "only decides what happens next"; AgentServer on `:gen_statem`; activation; crash keeps the last commit | Jido `guides/core-concepts/otp-concepts-for-jido.md` | Read |
| 22 | Agent as value; `cmd/3`; routes; candidate, commit, effects | Jido `definitions-instances-activations.md`, `signal-to-effects.md`, `turns-commits-and-effects.md` | Read |
| 22 | Signals follow CloudEvents 1.0 | Jido `guides/signals/cloudevents-envelope-and-context.md` | Read |
| 23 | Plugin callbacks; a handler may not change a plugin's field | Jido `guides/plugins/plugin-design.md` | Read |
| 23 | "Skill" in version 3 means a `SKILL.md` loader | Jido `guides/ai/tools-skills-and-toolsets.livemd`; migration guide | Read |
| 23, 24 | The Harness plugin: one activation, one conversation; command and result signal types; compiled only when Jido is present | Harness `guides/agent_plugin.md`, `plugin.ex`, `plugin/command.ex` | Read |
| 40 | Jido 3.0.0-beta.3; four packages merged; required dependencies include `req` and `req_llm` | Jido `README.md`, `mix.exs` | Read |
| 25 | A flow's parts; order from references; what is rejected at compile time; compiled to Runic | Jido `guides/flows/flows.md` | Read |
| 25 | Three authoring forms; stored documents pin targets to a catalog id and version; expressions are data | Jido `lib/jido/flow.ex`, `lib/jido/expr.ex`, `guides/flow-data/flow-identity-and-versioning.md` | Read |
| 25 | A wait holds no process; the two hosts that support waits; the example | Jido `guides/flow-runtime/flow-waits.md` | Read; excerpt copied |
| 25 | Durable runs: independent of AgentServer, saved at each part's boundary, no scheduler; a file store for one virtual machine | Jido `lib/jido/durable.ex`, `guides/storage/local-persistence-adapters.md` | Read |
| 25 | Topology: members and connections. Blackboard: snapshot, revision, conditional patch | Jido `guides/composition/composition-vocabulary.md`, `lib/jido/blackboard.ex` | Read |
| 25 | Runic's version is an alpha; Jido requires it | Jido `mix.exs`; Runic `mix.exs` | Read |
| 34 | Reactor: steps ordered by arguments, undo, a halted run returned as a value. Runic: workflows as data, a runner with a store. Journey: state in PostgreSQL | each project's `README.md`; Reactor `lib/reactor.ex`, `lib/reactor/step.ex`; Journey `mix.exs` | Read |
| 34 | Where "graph engineering" came from; LangChain's account; the study of 180 arrangements | pages linked from Stratta's `md/plans/2026-11-26-graphs/graphs.md` | Tool, and search excerpts |
| 34 | Code loaded into a node can reach everything the node can | Dune's README, for code that escapes its sandbox | Training; search excerpt |
| 12 | Sessions do not survive a restart; retention is bounded; sequence increases per resource | Harness `README.md`, `guides/overview.md` | Read |
| 18 | ACP methods; slash commands | `agentclientprotocol.com` | Tool, and search excerpts |
| 19, 40 | Hook decision format; no decision leaves the normal flow; 600 s default; a failure setting that denies | `code.claude.com/docs/en/hooks` | Tool, first 100,000 characters |
| 29 | Biscuit: public key, offline attenuation, blocks cannot be removed | the project's description | Search excerpts |
| 6 to 10, 15 | OTP behaviour of GenServer, Supervisor, Registry, DynamicSupervisor, Task, `:gen_tcp` | | Training; exercised by Labs 1, 2, 4 and 5 |
| 7, 40 | `terminate/2` runs on a supervisor's shutdown only if the process traps exits | GenServer's documentation | Training |
| 27, 29, 35 | OpenTelemetry vocabulary; `SO_PEERCRED`; SSH forwarding a Unix socket; the security terms | | Training |

## The labs

`verify/labs-solutions.txt`: seven files, 45 tests, 0 failures, Elixir 1.14.0 on Erlang/OTP 25.
`verify/labs-exercises.txt`: the same seven as stubs, every test failing, no compiler warnings.
Repeat runs of `02_supervision.exs`: in a first loop of six runs, one did not report a clean pass and
its output was not kept. The next 160 runs, 120 of them three at a time, all passed. The lab's timing
margins were then widened (waits of 2 s and 3 s in place of 0.5 s and 1 s), and 40 runs of that final
version all passed. The one unexplained run is listed in `NEXT.md`.
