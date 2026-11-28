# Borrowing PropertyDamage's method whole

**Date:** 2026-11-27

**Question.** An agent proposed a verification design assembled from several sources and labelled it an experiment. The operator asked whether it makes sense to build a system of one's own and run experiments on it when a lot of work has been done already, and whether to borrow all of PropertyDamage's method, or another, instead. What is "all of it", how does it meet this repository, and what would be left over?

**Sources read.** A checkout of `property-damage/property_damage` at `7bfa10a`: `CLAUDE.md` in full, `openspec/config.yaml`, one spec and the size of all thirteen, `.claude/skills/` (the ten OpenSpec skills by name, one read in part; `pd-model-interview` read to line 120 of 160), `.handoff/README.md`, `docs/decisions/README.md`, the CI workflow's job and step names, `.tool-versions`, and the history of `openspec/` over the last 50 commits. OpenSpec's own pages as search excerpts. repo-template's README at `2d094f4`. Not read: PropertyDamage's source, its tests, the OpenSpec tool's source.

**Method caveat.** Nothing was run. PropertyDamage needs Elixir 1.17 and Hex, and OpenSpec needs Node; neither was installed. What its author reads, reviews or skips is not visible in a repository, so nothing here says whether its code is read by a person.

---

## 1. The short answer

Borrow it whole. It is a written method that has produced a working library of 186 source files in the language Stratta is in, with the same agent tooling, and its subject is verification. The assembled design has produced nothing. The parts of that design which PropertyDamage's method lacks can be added one at a time when something shows they are needed.

Two things stay custom because they cannot be avoided: where its files go in a repository laid out from repo-template, and whether changes go through pull requests. Section 4 lists each collision.

One part of it answers the operator's aim more directly than anything in the assembled design: a skill that interviews the operator about how a system should behave, writes that down as the source of truth, and generates the tests from it.

## 2. What "all of it" is

| part | what it is in PropertyDamage's repository | its own standing |
|---|---|---|
| **Behaviour specs** | `openspec/specs/`, thirteen domains, 5,929 lines. Each requirement uses SHALL, MUST, SHOULD or MAY and has scenarios in WHEN and THEN | OpenSpec, a separate open-source tool: about 66,000 stars on GitHub, MIT, needs Node 20 |
| **The change workflow** | Ten OpenSpec skills and ten `/opsx:` commands in `.claude/`: propose a change, write its spec delta and tasks, apply, verify, archive | Ships with OpenSpec |
| **Decision records** | 67 numbered files in `docs/decisions/`. The first twenty were reconstructed after the fact, and the index says so; the specs were also written after the code | A common practice |
| **Pull requests with a handoff ledger** | One file per branch saying what was asked, what was decided and what was verified, written for a reviewer who takes ownership of the pull request | Its own |
| **The gauntlet** | Before a change is called done: `mix test`, `mix format --check-formatted`, `mix credo --strict`. CI adds compile with warnings as errors and a ceiling on dependency cycles. No gate command is piped | Ordinary Elixir tools |
| **Evidence standards** | A fix ships with a test shown failing against the old code. Anything that detects ships with a control proving it can fail. An untested module is driven end to end before it is trusted | Its own, four sentences |
| **Executed documentation** | A CI job runs every runnable code block in the guides | Its own script |
| **A pinned toolchain** | `.tool-versions`: Elixir 1.20.1 on Erlang/OTP 27.3.4 | Ordinary |
| **The library** | Generated sequences of commands against a real system, rules checked after each, failures shrunk | Hex package, first released 2026-01-16 |
| **The model interview** | A skill, `pd-model-interview`. It interviews the user about a system's behaviour and writes `model_spec.md`, which it calls the source of truth; the model's code is generated from it and can be regenerated | Ships in the repository; needs the library |

Two things in that table matter for Stratta in particular. PropertyDamage added its specs and its first twenty decision records to code that already existed, which is Stratta's position. And the interview skill refuses to derive a spec from code alone: its text says code may be wrong, and a spec that inherits its blind spots regenerates them with confidence.

## 3. How it meets the operator's aim

The aim is to build Stratta without reading its code by hand.

- **What the operator reads** would be the specs and each model's `model_spec.md`, both in prose, both written from what he says.
- **What tells him something is wrong** is a failing run shrunk to a few steps, which is what the spike on the timeline produced by other means.
- **What keeps a coding session honest** is the gauntlet in CI, the evidence standards, and a second reader on each pull request.

The assembled design said the same three things in its own words. It reinvented the first, and its "rules" are less than OpenSpec's specs plus an interviewed model spec.

## 4. Where it meets this repository

| PropertyDamage's method | this repository | what has to be decided |
|---|---|---|
| `openspec/` at the root | repo-template R3: every document is under `md/` | Use the tool as shipped and declare the folder an exception, or move it and lose the tool's defaults. Using it as shipped is the borrowing; moving it is customising |
| An OpenSpec change: a proposal, a design, tasks | A plan in `md/plans/`, and a step in `next.md` | Two ways to plan a change. The plain division: a plan and a step say what is next and why; an OpenSpec change is how one step's behaviour is specified and carried out |
| Pull requests, a reviewer, a ledger per branch | R29: push straight to `main`. `state.md` and `next.md` are the handoff, rewritten by `/end` | Whether code changes go through pull requests here. R29 lets `AGENTS.md` say so. The ledger and `state.md` do the same job at different sizes |
| Decision records | A plan numbers its decisions from D1; a governing document holds the rules | Keep this repository's forms; cite them from specs the way PropertyDamage's specs cite its records |
| Executed guides | The tutorial's `check_excerpts.py`, which checks its code excerpts against a checkout | The same idea already exists for the tutorial. It becomes a CI job if the tutorial comes into this repository |
| `.tool-versions` at Elixir 1.20.1 | `~> 1.19`, no pin | Settles the Elixir question in the same direction as [the analysis](../2026-11-27-elixir-1-20/elixir-1-20.md) |

## 5. What it does not contain

- **Checks held back from the coding session.** Its separation is a reviewer on a pull request, not tests the builder cannot see.
- **Seeded bugs in the code.** Its mutation mode alters what the adapter returns. It does not alter the code under test.
- **Races.** Its mode for concurrent sequences was removed, with the record saying it had detected nothing.
- **The front ends.**

Each of these is something to add if a defect shows it is needed, not before.

## 6. What is not known

- Whether the library fits a daemon tested inside its own node, with events that arrive after the command returns. The step in `next.md` that tries it stays.
- How much the OpenSpec workflow costs one operator who already keeps plans and steps.
- How large Stratta's specs get. PropertyDamage's are about 6,000 lines. That is more to read than a short list of rules, and less than the code.
- Whether the method leaves its author reading code.

## 7. Corrections to two earlier analyses

[PropertyDamage, read against Stratta](../2026-11-27-property-damage/property-damage.md) and [the verification design](../2026-11-27-verification-design/verification-design.md) both said that nothing in PropertyDamage's rules separates the agent that writes from whatever judges. That was wrong. `.handoff/README.md` describes a reviewer who takes ownership of each pull request. Both also described its specs as a format and missed that the repository runs the OpenSpec tool's whole workflow, and neither mentioned the interview skill. Both are corrected in place.

## 8. Recommendations

1. **Borrow PropertyDamage's method whole, and drop the assembled design.** The verification plan becomes a plan to adopt, not an experiment.
2. **Start with what needs no machine:** the gauntlet, the evidence standards and the no-piping rule in `AGENTS.md`; `.tool-versions`; a CI workflow with PropertyDamage's steps.
3. **Then OpenSpec as shipped,** at the root, declared as an exception to R3. The first spec is the timeline, written from the fourteen rules the spike used and the operator's two decisions on it.
4. **Then the library, on the operator's machine,** through the interview skill, on the smallest subsystem with a rule he fears breaking. This is where the library's fit is found out.
5. **Decide pull requests separately.** A second reader on each change is the method's answer to a builder grading itself. It is also the largest change to how this repository works.
6. **Keep what is already here:** the issues, the spike's scripts until a model replaces them, and repo-template's `state.md` and `next.md` as the handoff.
7. **Keep a short list of what the method lacks** (section 5), and add from it only on evidence.

## Sources

- `property-damage/property_damage` at `7bfa10a`.
- OpenSpec: <https://github.com/Fission-AI/OpenSpec>
