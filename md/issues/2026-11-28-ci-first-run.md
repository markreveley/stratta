# What CI's first runs found: tests that need the machine's git identity, a core with no lock file, and three warnings from Elixir 1.20

| | |
|---|---|
| What was checked | The gate in `core/`, `gui/` and `tui/`, on Elixir 1.19.7 and on Elixir 1.20.5, both with Erlang/OTP 28.5.0.9 |
| Commit | `b7a5708`, the code as it stood when the workflow was added |
| How | Run, by GitHub Actions: [run 46127403061](https://github.com/markreveley/stratta/actions/runs/46127403061). The logs of all six jobs were read. The report is [`md/tested/2026-11-28-0046-ci-first-run.md`](../tested/2026-11-28-0046-ci-first-run.md) |
| Rechecked | Item 1 at `986d034`, run: [run 46127755300](https://github.com/markreveley/stratta/actions/runs/46127755300) passes. Items 2 and 3 at `1c021fb`, run: unchanged |
| Reported | here only; no tracker entry |

## 1. Three tests pass only on a machine that has a git identity

- **Location.** `tui/test/cli_test.exs:68`, `core/test/thread_flow_test.exs:27`,
  `core/test/socket_test.exs:57`, and the cause of the hiding at
  `core/test/git_test.exs:44`, all at `b7a5708`.
- **Expected.** A test passes or fails by what the code does, on any machine.
- **Observed.** Each of the three has Stratta make a commit in a repository the test
  created. Git refuses to commit when it has no name and email for the author. A
  developer's machine has them in its settings; CI's machine has none.
  - In `tui/` the test failed: `stratta commit` printed git's
    `fatal: empty ident name ... not allowed` and returned exit status 1. 22 tests, 1
    failure.
  - In `core/` the two tests passed, for the wrong reason. A fourth test, in
    `git_test.exs`, sets the author's name and email in the environment of the whole
    test run and never clears them. That file's tests run first, so the other two found
    an identity that was not the machine's and not their own.
- **Evidence for the hidden half.** Run, on the branch `control/git-identity`
  (`a835fcd`), which is `b7a5708` with only those environment lines removed:
  [run 46127742404](https://github.com/markreveley/stratta/actions/runs/46127742404).
  Core goes from 23 passing to 3 failing: the two tests above and the test in
  `git_test.exs` itself.
- **What was done.** Each test's set-up now writes a name and an email into the
  repository it creates, and the environment is no longer set (`986d034`). Only test
  files changed.
- **What this is not.** It is not a defect in Stratta: committing as the operator, with
  the operator's own identity, is what it is meant to do, and on a machine with none it
  reports git's message and fails.
- **Status.** Fixed at `986d034`.

## 2. Core has no lock file, so core and the two front ends are tested against different versions of Harness

- **Location.** `core/` has no `mix.lock`. `gui/mix.lock` and `tui/mix.lock` exist.
- **Background.** A lock file records the exact version of every dependency, so that
  every build uses the same ones. Stratta takes Jido Harness from the tip of its `main`
  branch, not from a numbered release. Without a lock file, "the tip" is whatever it is
  on the day of the build.
- **Observed.** In the same run, core's job fetched Harness at `f810a4c`, and the app's
  job fetched it at `891e09b`, the commit in its lock file. The terminal client's lock
  file names `891e09b` too. So core's own tests ran against a newer Harness than the one
  the app and the terminal client run core against.
- **Why it matters.** A change in Harness can break core on a day when nothing in this
  repository changed, and the three apps can disagree about whether core works. Both
  passed today.
- **Proposed.** Add `core/mix.lock` with the same versions as the other two, and decide
  how Harness is updated: all three lock files move together, in one commit, with the
  gate run. The weekly run of CI is there to show a break that comes from outside
  ([ci.md](../docs/ci.md)).
- **Status.** Open. Not changed in this session: which Harness commit to lock is a
  choice, and a cloud session cannot run `mix deps.get` to write the file.

## 3. Elixir 1.20 reports three things that Elixir 1.19 does not

- **Location.** `core/lib/stratta/thread_server.ex:12`;
  `gui/lib/stratta_web/live/app_live.ex:251`; `tui/test/status_test.exs:85`. Line
  numbers at `b7a5708`.
- **Observed.** On Elixir 1.19.7 the three apps compile with no warning. On 1.20.5:
  1. `warning: unused require Logger`. The module asks for `Logger` and never uses it.
  2. `warning: this clause of defp busy?/1 is never used`. The function has a case for
     "no snapshot", and the type checker has worked out that it is never called with
     none.
  3. `warning: the following conditional expression ... will always evaluate to
     dynamic(:ok)`. A test's clean-up writes `delete_env(...) && File.rm(file)`, where
     the first half is always true, so `&&` is doing nothing.
  The first two fail the two compile steps in `core/` and `gui/` on 1.20, because those
  steps treat a warning as an error. The third is in a test file, which those steps do
  not compile; it is printed when the tests run. All tests pass on 1.20.5: 23, 3 and 22.
- **Why it matters.** This is the compile on 1.20 that
  [the analysis](../analysis/2026-11-27-elixir-1-20/elixir-1-20.md) asked to have read
  before deciding whether Stratta requires 1.20. None of the three is a bug a user would
  meet. Each is code that does nothing, which the newer compiler can now see.
- **Proposed.** If the operator decides for 1.20: remove the unused line, remove the
  unused case after reading why it was written, replace `&&` with two statements, and
  make the 1.20 jobs required.
- **Status.** Open; waits on the step in `next.md` that decides Elixir 1.20. Until then
  the 1.20 jobs report and do not fail the run.
