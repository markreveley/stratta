# `ThreadServer.terminate/2` may not run when the thread's process is stopped

| | |
|---|---|
| What was checked | `core/lib/stratta/thread_server.ex` and `core/lib/stratta/threads.ex` |
| Commit | `c387317` |
| How | Read. Not run |
| Rechecked | not yet |
| Reported | here only; no tracker entry. `next.md` already has the step that tests it |

## 1. The process does not trap exits

- **Location.** `thread_server.ex` line 208, `terminate/2`, which saves the timeline and
  closes the agent's session. `threads.ex` line 265 stops the process through
  `DynamicSupervisor.terminate_child/2`. Nothing in `thread_server.ex` sets `trap_exit`.
- **Expected.** Stopping a thread's process saves its timeline and ends its session.
- **Observed (read).** By OTP's rule, a GenServer that does not trap exits is killed by
  its supervisor's shutdown signal without `terminate/2` being called. If that holds
  here, deleting a thread leaves its agent's session to end some other way, and stopping
  the daemon inside the 400 ms save delay loses the last items.
- **Status.** Open. The two tests that settle it are a step in `next.md`. A model test
  with a restart command, as the verification plan proposes, would exercise the same
  path.
