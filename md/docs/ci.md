# CI: what runs on every push, and why

What this file is for: it says what the automatic checks are, the reason for each choice
in them, how to read a result, and what a pass does not tell you. It is written for the
operator, who decides what the checks should be, and for any agent about to change them.
The workflow file itself, [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml),
carries no comments, so the reasons are here. A change to that file changes this one in
the same commit.

## What CI is

*Continuous integration*, CI, is a machine that is not anyone's own, which takes each new
version of the repository, builds it from nothing and runs the checks. It matters here
for one reason: an agent saying "the tests pass" is a sentence, and a run on a machine
the agent does not control is a record. GitHub provides the machine (*GitHub Actions*)
and keeps each run's output for about three months.

The checks are **the gate**: the commands every change has to pass. `AGENTS.md` names the
same commands, so the gate on a developer's machine and the gate in CI are one thing.

## What runs

For each of the three apps, `core/`, `gui/` and `tui/`, on a fresh Ubuntu machine:

| step | command | what it catches |
|---|---|---|
| Fetch dependencies | `mix deps.get` | a dependency that has gone away or no longer fits |
| Dependencies as resolved | `mix deps` | nothing; it prints the exact versions fetched, for the record |
| Compile, warnings are errors | `mix compile --warnings-as-errors` | code that does not compile, and code the compiler thinks is wrong or unused |
| Compile for test, warnings are errors | `MIX_ENV=test mix compile --warnings-as-errors` | the same, for what is only built when testing |
| Format check | `mix format --check-formatted` | code not laid out the standard way |
| Tests | `mix test` | behaviour that a test describes and the code no longer has |

Each app is checked on two versions of Elixir, so a run has six jobs:

- **Elixir 1.19 with Erlang/OTP 28.** The versions Stratta requires. These three jobs
  decide whether the run passes.
- **Elixir 1.20 with Erlang/OTP 28**, marked *(advisory)*. These three report and do not
  decide.

It runs on every push to any branch, once a week (Monday 06:23 UTC, which is Sunday
night Pacific), and when started by hand from the Actions page. A run takes a little over a minute.

## How to read a run

- **The list of runs:** <https://github.com/markreveley/stratta/actions>. Each push is a
  row with a green tick or a red cross.
- **A commit's mark.** On the repository's front page, the tick or cross beside the
  latest commit is its run.
- **Inside a run,** each job is named by app and version, such as
  `core, Elixir 1.19, OTP 28`. A failed job opens at the step that failed, with the
  compiler's or the test's own message.
- **A green run with red advisory jobs is normal today.** The Elixir 1.20 jobs fail on
  two warnings ([the issue](../issues/2026-11-28-ci-first-run.md), item 3) and the run
  still passes.
- **A red run does not stop a push.** Changes go straight to `main`, and the run reports
  about a minute later. The rule in `AGENTS.md` is that whoever pushed reads the run and
  fixes a red one before doing anything else. Whether a red run should block instead is
  part of the decision on a second reader.

## The choices, and the reason for each

The workflow is borrowed from PropertyDamage's, the repository whose method Stratta has
adopted. Where it differs, the reason is given.

1. **Three jobs, one per app.** Stratta is three Mix projects. Separate jobs say which
   one broke, and run side by side.
2. **A warning is an error.** A warning that does not fail anything gets ignored, and
   then there are forty of them and the one that matters is not seen. This is also what
   makes the compiler's type checker useful: its findings arrive as warnings.
3. **Two compile steps.** The second builds what only exists for tests. PropertyDamage
   does the same.
4. **The versions are `1.19` and `28`, not exact numbers.** CI takes the newest patch
   release of each: today Elixir 1.19.7 and Erlang/OTP 28.5.0.9. One exact pair, in a
   `.tool-versions` file that CI and every machine read, waits on the operator saying
   what his machine runs.
5. **Elixir 1.20 as advisory jobs.** Whether Stratta should require 1.20 is the
   operator's open decision, and the analysis asked that one compile on 1.20 be read
   first. These jobs are that compile, on every push, at no cost to the run's result. If
   he decides for 1.20 they become the required ones. The Erlang version is kept the
   same in both so that a difference between the two is Elixir's.
6. **Every check runs even when an earlier one fails.** One push with a warning, a
   formatting slip and a failing test shows all three, not the first. The exception is
   a failed fetch of dependencies, after which nothing else can mean anything, so the
   rest are skipped.
7. **No cache.** PropertyDamage keeps built dependencies between runs to save time.
   Stratta does not yet: a cache is one more way for a check to pass on something stale,
   and a run takes about a minute without one. Add it when the wait starts to cost
   something.
8. **A newer push does not cancel an older run.** Each commit gets its own verdict, so
   it is always possible to say which commit broke something.
9. **Every branch, not only `main`.** A control branch has to be runnable (below), and
   if changes later arrive as pull requests their branches are already covered.
10. **A weekly run.** Core takes Jido Harness from the tip of its `main` branch and has
    no lock file ([the issue](../issues/2026-11-28-ci-first-run.md), item 2), so it can
    break on a day when nothing here changed. The weekly run shows that within a week,
    not at the next push.
11. **It can read the repository and nothing else.** The workflow asks for read access
    only. It cannot push, comment or change settings.

## Proving it can still fail

A check that has only ever passed has not been shown to work. `AGENTS.md` requires that
anything that detects ships with a control, and this is CI's:

```sh
git checkout -b control/ci-faults
bin/ci_control.sh seed
git add -A && git commit -m "Control, not for main"
git push origin control/ci-faults
```

The script writes, into each app, one function the compiler warns about, one file with
extra spaces, and one test that always fails. It refuses to run on `main`. The run on
that branch must fail four steps in every job: both compiles, the format check and the
tests, each on its seeded file. Anything else means a check has stopped checking.

Run the control after any change to the workflow file, write what it showed in
`md/tested/`, and delete the branch. Never merge it.

It was run when the workflow was added, and all twelve checks failed as they should:
[the report](../tested/2026-11-28-0057-ci-control.md).

## What a green run does not tell you

- **That the tests would notice a wrong change.** A test suite can pass and still miss a
  third of the bugs seeded into the code it covers; that was measured on the timeline
  ([the issue](../issues/2026-11-27-timeline-tests.md)). Closing that gap is what the
  specs and the generated tests are for.
- **Anything about macOS.** CI runs on Linux. The operator runs Stratta on a Mac.
- **Anything about a real agent.** The tests start the bundled demo agent.
- **That the terminal program starts.** Its modules are tested; `stratta` itself is not
  built.
- **That a page loads.** The app has three tests, all of Markdown rendering.

## Not in it yet

- `mix credo --strict`, a second kind of code check that PropertyDamage's gate has. It
  joins after one run of it on Stratta has been read, so that what it reports can be
  looked at before it is able to fail a push.
- The tutorial's checks and the layout check, which agents run by hand before pushing.
  They need only Python and would fit as a fourth job.
- A build of the `stratta` program.
- PropertyDamage's other jobs, which have no counterpart here yet: its count of
  dependency cycles, its check that every example in its documentation runs, and its
  browser tests.
- A second reader for each change. That is the operator's decision to make.

## What its first runs found

The first run was also the first time the suite ran on the versions Stratta requires.
One test failed, for a reason that had been hiding two more.
[The report](../tested/2026-11-28-0046-ci-first-run.md) has the results and
[the issue](../issues/2026-11-28-ci-first-run.md) has the three findings.
