# PropertyDamage, read against Stratta

**Date:** 2026-11-27

**Question.** The operator pointed at PropertyDamage as the place to start on verification. What is it, how far can its documentation be trusted, and what would it and would it not do for Stratta?

**Sources read.** The HexDocs pages for v0.2.0 (the main page, the README, the Model module, the guides on invariants and on integration testing). Hex's package pages. A checkout of `property-damage/property_damage` at `7bfa10a` (2026-11-14): `CLAUDE.md`, `mix.exs`, `CHANGELOG.md`, `openspec/config.yaml`, one spec, the guides on coverage and on mutation testing, decision records DR-062, DR-063 and DR-064, the CI workflow, and the names of everything else. Stratta at `c387317`. Not read: the library's source, its tests, its benches beyond their names.

**Method caveat.** The HexDocs pages were read through a tool that returns a summary. PropertyDamage was not run: `main` needs Elixir 1.17, and the session that wrote this had 1.14 and no access to Hex. Everything about how it would behave against Stratta is a reading.

---

## 1. The short answer

PropertyDamage is the right shape for testing Stratta's daemon, and it is young and changing fast. The page the operator linked describes two features that have since been removed. It is worth a spike with a yes or no at the end, not a commitment. Its repository is as useful as the library: it is built with agents and writes down how it keeps them honest.

## 2. What it is

A framework for testing a system as a state machine with generated input.

- A **model** lists commands, with weights and conditions for when each may run.
- An **adapter** runs each command against the real system and returns **events**.
- **Projections** fold commands and events into state, and carry the checks.
- A sequence that fails is **shrunk** to the shortest one that still fails, saved so it can be replayed, and can be written out as an ordinary ExUnit test.
- It uses StreamData to generate values.

Beyond generation it has three things the [verification design](../2026-11-27-verification-design/verification-design.md) wants:

- an **invariant catalog**: each check names the rule it validates;
- **coverage per rule**: a run reports a rule whose check never fired;
- a **mutation mode** that alters what the adapter returns, to see whether the checks notice.

It also has words for a command whose effect arrives later (`:async`, `:probe`, and waiting for the system to settle), which is how every agent event reaches Stratta.

## 3. How far the documentation can be trusted

The page linked is for v0.2.0. The code has moved.

| the v0.2.0 page says | `main` at `7bfa10a` |
|---|---|
| branching sequences, with linearizability checking | removed on 2026-11-06 (DR-063). The record says the branches never overlapped at the system under test, so the mode detected no race |
| fault injection | removed on 2026-11-06 (DR-062) |
| `@trigger`, `assertion_projections/0` | `@check`, `check_projections/0` |
| Elixir 1.14 or later | Elixir 1.17 or later |

Its `CLAUDE.md` says the project is before v1 and prefers a breaking change to a deprecation.

## 4. How mature it is

- Hex shows a first release on 2026-01-16 and no package that depends on it.
- The 50 most recent commits have one author.
- The repository has 186 source files and 67 decision records.
- Licence: Apache-2.0.

## 5. Its repository as an example

It is built with agents, and its rules for them fit in 128 lines:

- Behaviour is specified in 13 domains under `openspec/`, with RFC 2119 words, every requirement with a scenario.
- Decisions are numbered records with their reasons.
- A list of commands must pass before a change is called done, and none of them may be piped, so the exit code is the command's.
- A fix ships with a test shown failing against the old code.
- Anything that detects ships with a control proving it can fail: a seeded bug, or a removed rule.
- A CI job executes every runnable code block in the guides.

Nothing read there separates the agent that writes the code from whatever judges it.

## 6. What it would do for Stratta

Read, not run:

- **Commands** are `Stratta.API` operations: create a thread, send, answer a request by label, interrupt, set a slot, delete, restart the thread's process.
- **The adapter** calls the API inside the daemon's node. The guides are written around HTTP services; the repository has benches against Cachex and Oban, which are not, and they were not read.
- **Events from the agent** arrive after the command returns. `:async` and `:probe` commands exist for that.
- **The agent** would be the demo agent, or the scripted one that misbehaves which [adversarial-boundaries](../../plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md) Phase 0 proposes.
- **The rules** are the ones Stratta's README already states: a label is never reused; an answer goes to the request it names; history survives a restart.

It would exercise the path that [the terminate issue](../../issues/2026-11-27-thread-server-terminate.md) is about, because a restart is a command.

## 7. What it would not do

- **Races.** Its concurrency mode was the one removed. Races between the thread's process, the socket and subscribers need something else.
- **The front ends.** Nothing here tests the app or the terminal client.
- **The pure modules.** For the timeline fold, diff parsing and label arithmetic, plain StreamData is less machinery. The spike on the timeline used it directly.

## 8. Recommendations

1. **Investigate it with a spike**, on a machine with the versions Stratta requires. Six commands, the demo agent, five rules. The spike answers four things: does an adapter inside the node work with events that arrive later; does a failure shrink to something readable; does the coverage report a rule that never fired; how long do 100 sequences take against a real Harness session.
2. **Pin a commit** if it is used, and expect the names in the docs and in the code to differ.
3. **Keep the fallback open.** The spike's pattern on the timeline (a generated list of operations run against the real code and a small model) works with StreamData alone and can be carried to the API. "No, use that" is a possible answer.
4. **Take its evidence standards whatever the spike says.** They do not need the library.

## Sources

- <https://property-damage.hexdocs.pm/PropertyDamage.html> and the pages linked from it.
- <https://hex.pm/packages/property_damage>
- `property-damage/property_damage` at `7bfa10a`.
