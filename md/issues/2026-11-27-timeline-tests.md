# The tests: nothing runs them automatically, and what a seeded bug in the timeline shows they miss

| | |
|---|---|
| What was checked | `core/test/timeline_test.exs` (10 tests) and eleven generated properties, against 85 one-change mutants of `core/lib/stratta/timeline.ex`; and the repository for anything that runs the tests |
| Commit | `c387317` |
| How | Run: Elixir 1.14.0 on Erlang/OTP 25, `timeline.ex` by itself. [`mutate.py`](../analysis/2026-11-27-verification-design/spike/mutate.py) makes the mutants and `run.sh CHECKOUTS mutants` runs both sets of tests against each. The result for every mutant is in [`mutation-results.tsv`](../analysis/2026-11-27-verification-design/spike/mutation-results.tsv) |
| Rechecked | not yet |
| Reported | here only; no tracker entry |

A *mutant* is the module with one small change: `==` to `!=`, `"pending"` to
`"expired"`, one step removed from a pipeline. A test suite *kills* a mutant when at
least one test fails on it. A mutant that survives is a change to behaviour that no test
notices. Some survivors are changes that make no difference; the rest are behaviour
nothing checks.

## 1. Nothing runs the tests automatically

- **Location.** The repository has no CI configuration.
- **Observed.** `state.md` records that `mix test` has not been run on the versions
  Stratta requires since `timeline.ex` last changed. The first run on those versions is
  a step in `next.md`.
- **Status.** Open. The verification plan's first phase.

## 2. Thirty-six in a hundred seeded bugs pass every test

- **Observed.** 85 mutants; 81 compiled.

  | | killed | of 81 |
  |---|---|---|
  | the 10 existing tests | 45 | 56% |
  | the 11 properties, 200 runs each | 37 | 46% |
  | either | 52 | 64% |
  | neither | 29 | 36% |

  The two sets catch different things: 15 mutants only the existing tests kill, 7 only
  the properties kill.
- **Caution.** These figures describe one module and one script's choice of changes. No
  figure here is a target.
- **Status.** Open.

## 3. What the 29 survivors are

Grouped by the behaviour they change. Line numbers are `timeline.ex` at `c387317`.

1. **What a restart does to open tool calls** (lines 133, 141, 142; six mutants). No
   test asserts that a restart interrupts a tool call, or which statuses count as open.
   This is the code behind items 3 and 4 of [the fold](2026-11-27-timeline-fold.md).
2. **Where command output goes** (lines 209 to 213 and 373; five mutants). No test
   asserts that output is added to the latest tool call of the turn, that it
   accumulates, or that it falls back to the reply when the turn has no tool call.
3. **Which plan item a plan update replaces** (lines 232 and 234; four mutants). No test
   has two turns with plans.
4. **The alternative names of payload keys** (lines 183, 201, 203, 245, 252, 254, 286,
   304, 344; nine mutants). `toolCallId` or `tool_call_id`, `rawInput` or `raw_input`,
   and the defaults used when a key is missing. Some of these make no difference.
5. **Usage** (line 282; one mutant). No test asserts that usage is cleared after it is
   attached to a turn's end.
6. **`cursor`** (line 163; two mutants). Item 6 of [the fold](2026-11-27-timeline-fold.md).
7. **Label arithmetic** (line 74; one mutant) and **the time on an item** (line 397; one
   mutant). Probably no difference in behaviour.

- **Status.** Open. Each group is either a rule to write down and check, or a change
  recorded as making no difference.
