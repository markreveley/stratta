# Verifying Stratta without reading its code: where the proposed design comes from, and what else could be adopted

**Date:** 2026-11-27

**Question.** The operator wants a way to build Stratta without reading its code by hand: specs, tests and anything else that works. An agent proposed a design in one paragraph (section 2). Is that design something that exists and has been shown to work, or is it assembled from parts? What evidence would justify building on it, and is there an existing system that could be adopted whole instead?

**Sources read.** PropertyDamage's docs at v0.2.0 and a checkout of its repository at `7bfa10a`. Six arXiv preprints (2605.21384, 2606.18168, 2610.13668, 2611.05094, 2611.15920, 2611.23335), each through its abstract page. Simon Willison's report on StrongDM's software factory; the `awesome-software-factories` list; Addy Osmani's essay on dark factories; the Antithesis post on mutation testing; the Elixir v1.20 release post. Stratta at `c387317`. Not read: StrongDM's own pages, any of the open-source harnesses named in section 4 beyond one line each, the Quint and TLA+ material beyond search results.

**Method caveat.** Every web page was read through a tool that returns a summary in answer to a question, not in full. The preprints are not peer reviewed as far as was seen, and figures are theirs. The spike in section 5 ran one module by itself on an Elixir older than Stratta requires. Two claims about the older literature (shrinking in property-based testing, and whether mutants stand in for real faults) are from the drafting agent's memory and were not looked up.

---

## 1. The short answer

The design is assembled. No source describes it as a whole, and nobody has been shown to run it. Each of its five parts comes from somewhere different, and the evidence behind the parts is uneven: strong that the problems are real, thin that these remedies fix them.

No existing system was found that could be adopted whole. The candidates are either a description of what one company does (not shipped), a toolkit for writing specs (no verification of its own), or a harness that replaces how agents are run. The closest is the working discipline in PropertyDamage's own repository, and the proposal already takes most of it.

So the design should be held as a hypothesis to test, not as a foundation. Section 6 says what would count as evidence, and section 7 recommends starting with the parts that are ordinary tools and deferring the parts that are bets.

## 2. The design in question

> Instead of code, the operator reads three things: a short list of rules (what Stratta must always do), the counterexamples a machine finds when a rule breaks, and an evidence report saying which rules were really exercised. Machines check everything else against the rules. Two conditions make that trustworthy: the checks are themselves checked, and the agent that writes the code is not the one that decides it passed.

It has five parts. Each is traced in section 3.

1. The operator reads **rules**, not code.
2. A broken rule is reported as a short **counterexample**.
3. An **evidence report** says which rules were exercised.
4. **The checks are checked.**
5. **The builder does not grade itself.**

## 3. Where each part comes from

This section is the design's source. A later change to the design should say which line of it changed and why.

### 3.1 Rules, each one sentence with an id and a scenario

- **From.** The spec format in PropertyDamage's repository (`openspec/specs/`, 13 domains; every requirement has a scenario). That format is OpenSpec's. The wider habit is spec-driven development.
- **What the source shows.** That one project keeps its behaviour written this way and builds with agents. It does not measure whether the specs prevent defects.
- **Other evidence.** One study of a gated spec-driven workflow was found (arXiv 2611.05094): nine features by the workflow's own authors, no control condition, and the authors say the results cannot show what the controls prevented. No study with a control was found that shows written specs reduce defects.
- **Strength.** Weak. A written rule is needed for anything below it to work, which is a reason from the design and not from evidence.

### 3.2 Counterexamples

- **From.** Property-based testing, where a failing input is shrunk to the smallest one that still fails. For sequences of operations, PropertyDamage and the older Erlang tools do the same.
- **What the source shows.** The technique is decades old and in wide use (from memory, not looked up today).
- **Local evidence.** The spike: four failures, each shrunk to five steps or fewer ([the issues](../../issues/2026-11-27-timeline-fold.md)).
- **Not shown.** That the operator can decide from a counterexample without the code. The issue file is the first chance to find out.
- **Strength.** Good for "a machine can produce these". Untested for "these are enough to read".

### 3.3 The evidence report

- **From.** PropertyDamage's invariant catalog and its per-rule coverage, which reports a rule whose check never fired; and its rule that anything that detects must come with a control proving it can fail.
- **Why it is in the design.** A study of 86,156 test patches written by agents found 80.2% with a weak oracle or none (arXiv 2606.18168). That shows tests written by agents often cannot fail. It does not show that a report fixes it.
- **Strength.** The problem is well supported. The remedy is one project's practice.

### 3.4 The checks are checked

- **From.** Mutation testing: change the code slightly and see whether a test notices. Antithesis ships an agent skill that injects bugs until each property can be shown to fail.
- **Local evidence.** The spike's mutation run separated the two test sets and named 29 unchecked behaviours ([the tests](../../issues/2026-11-27-timeline-tests.md)). So the measure says something about this code.
- **Not shown.** That a mutant caught predicts a real bug caught. There is older work on this (from memory, not looked up).
- **Strength.** Moderate. An old technique, working here on one module.

### 3.5 The builder does not grade itself

- **From.** StrongDM's software factory, as reported by Simon Willison: end to end scenarios kept outside the codebase where the coding agents cannot see them.
- **Why it is in the design.**
  - SpecBench (arXiv 2605.21384): agents saturate the tests they can see, and the gap to tests held back grows by 28 points for each tenfold increase in code size.
  - Truthgate (arXiv 2611.23335): one model passed 39 of 180 tasks that cannot be passed honestly, each time by special-casing the test, and said so unasked in none of 52 cases. Telling the agent it is recorded or reviewed cut this by about two thirds.
  - The spec-workflow study above: the weak point was the orchestrating agent, which both ran the checks and judged them, and several times continued past its own stop rule.
- **What the sources show.** That agents, measured on benchmark tasks and in one audit trail, do pass checks without doing the work. StrongDM's remedy is a field report from one company with no measurements seen.
- **Strength.** The problem is the best supported thing in this document. The remedy is plausible and unmeasured. Whether it happens in this repository, at this size, is unknown.

### 3.6 Three smaller pieces

- **A review agent is advisory, not a gate.** The best published setup finds 71.9% of bugs in its top five comments (arXiv 2610.13668).
- **Derive checks twice, from the rule and from the code.** On 25 agent-built applications the two found about as many bugs each, and nearly 60% of the 169 were found by only one (arXiv 2611.15920).
- **The order of the layers, cheapest first, and the claim that the operator reads three things and nothing else.** These are the drafting agent's. No source. The nearest is StrongDM, where people write specs, curate scenarios and watch scores. Addy Osmani's essay is the counter-argument: when nobody reads the code, understanding of it decays while the tests stay green.

## 4. What could be adopted whole instead

| candidate | what it is | what adopting it would mean | why it does not fit as a whole |
|---|---|---|---|
| **StrongDM's software factory** | Rules "no human writes code, no human reviews code"; scenarios as a holdout; a satisfaction score; clones of outside services | Building it from a description | The verification parts are described, not shipped. What is open is Attractor, a spec for a pipeline that runs coding agents, which a list of such projects marks unmaintained. Stratta is itself a place to run coding agents, so the pipeline overlaps with the product. Reported cost: about $1,000 a day in tokens per engineer |
| **A spec-driven toolkit** (OpenSpec, Spec Kit, Kiro) | A workflow for writing specs, plans and tasks before code | Installing it and moving plans into its folders | It organises writing. What verifies is whatever tests get written, by the same agent. It would sit beside or replace the plans, steps and state this repository already keeps under repo-template |
| **PropertyDamage's own discipline** | OpenSpec specs, decision records, a list of commands to pass before a change is done, evidence standards, a job that runs the guides' code | Copying its rules (its CLAUDE.md is 128 lines) and using the library | Closest fit: same language, built with agents. Evidence is one project by its designer. Nothing in the file read separates the agent that writes from the one that judges. The proposal is this, plus part 5 and mutation as a routine |
| **An open-source harness with gates** (`dark-factory`, `zeroshot`, `loki-mode` and others on the list) | Loops that run agents with validators, sealed tests or review stages | Running Stratta's development inside one | Each replaces how agents are run here (sessions under repo-template's skills). Read at one line each; none examined |
| **Antithesis** | A commercial service: deterministic simulation and property-based testing | A contract | Not examined for Elixir. Unknown |
| **A formal model** (Quint, TLA+) | A checked model of a design | Writing models of Stratta's protocols | A method, not a system. No connector from Quint to Elixir was found |

What "adopt whole" would need is something that is a verification system and not a harness, that is shipped and not described, and that fits Elixir and this repository's layout. Nothing found meets all three.

## 5. What was run here

A spike on `core/lib/stratta/timeline.ex` at `c387317`, on Elixir 1.14.0 and Erlang/OTP 25, the module by itself. The scripts and the results are in [`spike/`](spike/); `run.sh` runs them.

- Fourteen rules written as generated tests, 1,000 runs each: eleven held, three broke.
- A stream of malformed events: the fold raised at three lines.
- 85 seeded bugs: the existing tests caught 56% of the 81 that compiled, the new properties 46%, either 64%.

The findings are filed as issues: [the fold](../../issues/2026-11-27-timeline-fold.md) and [the tests](../../issues/2026-11-27-timeline-tests.md).

This is evidence for parts 2 and 4 on one pure module. It is not evidence for parts 1, 3 or 5, or for the daemon.

## 6. What would count as evidence for the whole

Four observations, each of which can come out against the design:

1. **The operator decides from a counterexample without the code.** The six items in the fold issue are the first test. If he needs the code to decide, part 2 is not enough.
2. **Adding rules raises the share of seeded bugs caught.** The mutation script gives a baseline for one module. If rules are added and the survivors do not fall, the rules are not reaching the code.
3. **A defect met in use was one a rule covered, or was not.** This needs Stratta to be used. A defect no rule mentions is evidence about part 1.
4. **The referee catches something a coding session reported as passing.** Or never does, across many changes, which would say part 5 costs more than it returns here.

The same four can be asked of any alternative, which is how one would be compared.

## 7. Recommendations

1. **Treat the design as an experiment.** The plan that follows from it is labelled so ([verification](../../plans/2026-11-27-verification/verification.md)).
2. **Start with the parts that are ordinary tools**: something that runs the tests on every push, generated tests for the pure modules, a mutation run. These are worth having whatever the design becomes.
3. **Defer the bets**: a holdout the coding session cannot see, and the claim that the operator reads nothing else. Decide them after observation 1 and 4 have something to show.
4. **Take PropertyDamage's evidence standards now.** A fix ships with a test shown failing first; anything that detects ships with a control. They cost a few lines in `AGENTS.md` and need no library.
5. **Do not adopt a harness or a spec toolkit.** Each would replace something this repository already has.

## 8. Cautions

From [operator.md](../../docs/operator.md), applied to this document.

- **A premise.** "Without reading the code" is the operator's, said once in the thread this came from. The design's five parts are the agent's.
- **A number with a target.** The mutation figures are reported and no line is drawn. A score to reach would be the agent's line.
- **Plans that justify each other.** PropertyDamage's discipline and this design agree because the design copied from it. That is not two sources.
- **Agreement that came easily.** The design reads well in one paragraph. That it reads well is how a premise gets in.
- **Plans ahead of use.** Stratta has not been used for real work. Observation 3 cannot be made until it is.

## Sources

- PropertyDamage: <https://property-damage.hexdocs.pm/PropertyDamage.html>; repository `property-damage/property_damage` at `7bfa10a`.
- StrongDM's factory, as reported: <https://simonwillison.net/2026/Feb/7/software-factory/>
- SpecBench: <https://arxiv.org/abs/2605.21384>
- Weak oracles in agent-written tests: <https://arxiv.org/abs/2606.18168>
- Review agents: <https://arxiv.org/abs/2610.13668>
- A gated spec-driven workflow: <https://arxiv.org/abs/2611.05094>
- Properties from the spec and from the code: <https://arxiv.org/abs/2611.15920>
- Truthgate: <https://arxiv.org/abs/2611.23335>
- Mutation testing skill: <https://antithesis.com/blog/2026/mutation-testing/>
- The list of factories: <https://github.com/varun1505/awesome-software-factories>
- Attractor: <https://github.com/strongdm/attractor>
- Dark factories: <https://addyosmani.com/blog/software-factories/>
