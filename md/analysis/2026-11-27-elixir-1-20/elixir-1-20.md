# Should Stratta require Elixir 1.20?

**Date:** 2026-11-27

**Question.** Stratta's three apps say `elixir: "~> 1.19"`. Elixir 1.20 has a type checker that finds bugs with no annotations. Should Stratta require 1.20, for what it would verify?

**Sources read.** The Elixir v1.20 release post (2026-06-03) and the January 2026 post on the first release candidate; the v1.20 changelog and the compatibility table on HexDocs, as search excerpts; `mix.exs` in `core/`, `gui/` and `tui/` at `c387317`; the CI workflow of `agentjido/jido_harness` at `f810a4c`; `mix.exs` of PropertyDamage at `7bfa10a`. An earlier conversation of the operator's on set-theoretic types in 1.20, from April 2026, when 1.20 was a release candidate.

**Method caveat.** Elixir 1.20 was not run. The session that wrote this had Elixir 1.14. What the checker would report on Stratta's code is not known; section 4 is reasoning. The release post was read through a summarising tool. Two secondary sources disagree on what Elixir 1.21 will contain.

---

## 1. The short answer

Yes, with two conditions: do it when something runs the compiler with warnings as errors on every push, and after one compile on 1.20 has shown what it reports. Without the first, the checker's warnings scroll past and verify nothing. Requiring 1.20 costs little: the Harness is already tested on it.

It would not have found any of the defects filed on 2026-11-27. It finds a different kind.

> Added 2026-11-28. Both conditions are now met. CI compiles with warnings as errors on
> every push, and runs each app on Elixir 1.20.5 without failing the run. That compile
> reports three things 1.19.7 does not: an unused `require`, a function clause that is
> never reached, and a condition that is always true. Every test passes on 1.20.5. The
> details are [item 3 of this issue](../../issues/2026-11-28-ci-first-run.md).

## 2. What the requirement means today

`~> 1.19` means 1.19.0 or later, below 2.0. So 1.20 is already allowed, and a machine with 1.20 already gets its checker. What the line does not do is make every machine use it. A session on 1.19 compiles the same code with a weaker checker and sees fewer warnings.

"Requiring 1.20" is two changes:

- `elixir: "~> 1.20"` in the three `mix.exs` files. This is a floor: 1.20 or later.
- A `.tool-versions` file naming one exact Elixir and one exact Erlang/OTP, which version managers (asdf, mise) and CI read. This is what makes every session use the same compiler.

## 3. What the 1.20 checker does

From the release post:

- It infers types for every language construct and every function, with no annotations.
- It reports only what it calls verified bugs: a violation that is certain to fail at runtime if that code runs. The examples given: passing a value that can only be an integer or a string to a function that needs a map; reading element 3 of a tuple known to have fewer than 3; reading a key known to be absent; using a value as a number after it has been narrowed to a map.
- It reports clauses that can never match, which is dead code.
- It reports nothing when it cannot be certain. A value of unknown type is tracked as a range of possibilities, and a warning appears only when a use falls outside the whole range.

What it does not have yet: type signatures a person writes, typed struct fields, recursive and parametric types.

Elixir 1.20 needs Erlang/OTP 27 or later and works with 29. Stratta's README asks for OTP 28.

## 4. What it would and would not catch here

Reasoning, not run.

- **Would not catch** the timeline defects in [the fold issue](../../issues/2026-11-27-timeline-fold.md). Items 1 to 4 are behaviour: the code does what it says, and what it says is wrong or undecided. Item 5, the raises on a malformed payload, comes from data that arrives as decoded JSON. The checker cannot know the shape of a map that came from outside, so it tracks it as unknown and stays silent.
- **Could catch** a call with the wrong shape between Stratta's own modules, a pattern that can never match after a refactor, and a misuse of a struct field. Stratta's own structs (`Timeline`, the thread record, `Jido.Harness.Event`) are where it knows most.
- **Unknown** how many warnings Stratta's code produces on 1.20 today. That is the one compile in the short answer. (Since run: three. See the note in section 1.)

For an agent writing the code, the gain is feedback on the next compile with no annotations to write. That was the point made in the operator's April conversation, and the release kept it. That conversation also recorded that the release candidates lost type information across modules; the final release says it uses types from the standard library and from dependencies.

## 5. What it costs

- **The operator's machine** needs 1.20. Whether it has it is not known here.
- **Dependencies.** `jido_harness` requires `~> 1.19` and its CI tests two pairs: Elixir 1.19 on OTP 28, and Elixir 1.20 on OTP 29. PropertyDamage requires `~> 1.17`. Phoenix and LiveView were not checked.
- **Cloud sessions** are not affected: they have 1.14 and cannot run the suite under either requirement.
- **Later versions.** A floor does not block 1.21. Sources disagree on whether typed structs and signatures arrive in 1.21 or later, and no release of 1.21 was found.

## 6. Recommendations

1. **Raise the floor to `~> 1.20`** in the three `mix.exs` files, and add `.tool-versions` with the exact pair the operator's machine runs.
2. **Do it together with the gate** in the verification plan's first phase: `mix compile --warnings-as-errors` on every push. The checker verifies something only where a warning stops the change.
3. **First compile once on 1.20** and file what it reports as an issue, so the gate does not start red for reasons nobody has read.
4. **Keep OTP 28 as the stated minimum** unless that compile says otherwise.

## Sources

- <https://elixir-lang.org/blog/2026/06/03/elixir-v1-20-0-released>
- <https://elixir-lang.org/blog/2026/01/09/type-inference-of-all-and-next-15/>
- <https://hexdocs.pm/elixir/compatibility-and-deprecations.html>
