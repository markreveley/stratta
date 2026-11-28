# Does PropertyDamage's method win? A wider look, in any language

**Date:** 2026-11-27

**Question.** Borrowing PropertyDamage's method becomes this repository's methodology, so the operator asked for one more search before committing: how are people approaching the verification of agent-written software in November 2026, in any ecosystem, and does anything beat it?

**Sources read.** A news summary of the Claude Code team's post on verification (16 November 2026); arXiv 2610.34577 on verification designs in agent harnesses; arXiv 2610.08651, a case study of assuring agent-written software; arXiv 2605.15229 (PBT-Bench); a practitioner's scan of verification practices (`eitri-edd/AI-PDLC` issue 122); Kiro's announcement of property tests drawn from specs, and two reviews of it; five comparisons of spec-driven tools; Antithesis's pages on Hegel and its agent skills; the vericoding benchmark's abstract; Hex and GitHub pages for PropCheck and PropEr. Earlier today: the sources of [the verification design](../2026-11-27-verification-design/verification-design.md) and [the borrowing analysis](../2026-11-27-borrowing-property-damage/borrowing-property-damage.md).

**Method caveat.** Every page was read as a summary or a search excerpt. The Claude Code post was read through a news article about it, not directly. Dan Luu's study of how agents use testing techniques could not be fetched and is known here only from a search excerpt. Nothing was run. A search finds what is written about, which favours vendors and people who publish.

---

## 1. The short answer

Nothing found beats it for this repository, and nothing found is a single winning method anywhere. What has converged, across vendors, papers and practitioners, is a shape. PropertyDamage's method has that shape on most points and is the only shipped instance of it found for Elixir.

The commitment is smaller than it looks, because it is two commitments. The method (specs in OpenSpec, a gate, evidence rules, a second reader) is made of standard parts, each replaceable. The library is the young part, and it can be swapped for an older one without changing the method.

## 2. The shape that has converged

Five things recur in sources that do not depend on each other.

1. **Checks the agent can run that do not share its bias.** The Claude Code team names end-to-end, property and differential tests. A practitioner's scan of the field rated "property-based testing as the bridge from spec to check" highest of its fifteen proposals. Kiro ships the idea: requirements written in a fixed form, properties extracted from them, tested with generated input.
2. **A judge that is not the builder.** In a comparison of seventeen verification designs across seven models, a separate critic in a fresh context gave the largest gains (5.9 to 9.5 points on one benchmark at 1.13 to 1.25 times the cost), and asking the agent to check itself at the end gave little for more. The Claude Code team reads its review rules from the base branch, so a change cannot edit the rules that judge it, and ties each review to a commit.
3. **Checks on the checks.** A case study of a production system built by agents confirmed its tests by seeding failures, and still found monitors that watched a proxy, an audit that had stopped without failing, and a pass rate that dropped missing checks from its total. Its four questions for any check: does it observe the outcome or a proxy; is there evidence it ran; do missing results stay visible; is its authority limited.
4. **A written spec as what people review.** Spec Kit, OpenSpec, Kiro and BMAD are the tools named everywhere. Comparisons repeatedly put OpenSpec with existing codebases and small reviewed changes, and Spec Kit with new projects. Only Kiro attaches verification to the spec.
5. **Structure for the agent's testing.** Told to use property tests, agents find more seeded bugs than when left alone (31 to 77 percent of them unprompted, 42 to 83 with guidance, across eight models). One practitioner's study found agents used a property-testing library superficially when merely handed it.

## 3. The alternatives, as wholes

| approach | what it is | why it does not displace PropertyDamage's method here |
|---|---|---|
| **Kiro** | An IDE and CLI from AWS: requirements, design and tasks per feature, with property tests drawn from the requirements | Closest in idea. It means working inside Kiro. Its property tests are optional and, per one review, in the IDE only. The libraries named for it are Python's and TypeScript's; none for Elixir was found |
| **Spec Kit, BMAD, Tessl** | Spec frameworks | No verification of their own. Spec Kit is aimed at new projects, BMAD at teams with product documents, Tessl is partly closed |
| **Antithesis** | Deterministic simulation as a service, with open tools: Hegel for property tests, Bombadil for web and terminal interfaces, and agent skills for both | Hegel's libraries are for Rust, Go, C++, TypeScript, Java and OCaml. The service is commercial and was not examined for the BEAM. Bombadil is the one piece that fits Stratta, for its two front ends |
| **Proof** (Dafny, Verus, Lean) | The agent writes code and a machine-checked proof | Moving fast: one benchmark has off-the-shelf models succeeding on 82% of Dafny tasks and 27% of Lean ones. It needs a language with a verifier. Elixir has none |
| **The Claude Code team's practice** | A `verify` skill beside the code, a gate on commits, owner-written checks, a tuned reviewer with protected rules | A set of practices from one team, not a package. Much of it overlaps PropertyDamage's method; the rest is section 4 |
| **A software factory with held-back scenarios** | StrongDM's arrangement | Described, not shipped |
| **Review agents alone** | A second model reads the change | The best published reviewer finds about 72% of bugs in its top five comments. Useful as the second reader, not as the method |

For the library itself, in Elixir:

| library | standing | for this job |
|---|---|---|
| **PropertyDamage** | First released January 2026; one author; changing | Rule catalog, per-rule coverage, replay files, the interview skill. Not yet run here |
| **PropCheck** (on PropEr) | Version 1.5.0; a decade old; last pushed April 2025; GPL-3.0 | Mature state-machine testing, including parallel runs. None of the catalog, coverage or interview. The licence is one to look at before depending on it |
| **StreamData** | Maintained in the Elixir organisation | No state-machine support. The spike on the timeline wrote its own small interpreter for sequences |

## 4. What the wider practice has that PropertyDamage's method lacks

Kept as a list to add from on evidence, as [the borrowing analysis](../2026-11-27-borrowing-property-damage/borrowing-property-damage.md) recommends, not to add now:

- Review rules read from the base branch, and a review tied to the commit it read.
- A check on the front ends by driving them, which is what Bombadil is for.
- The four questions about a check, from the case study.
- Differential testing against an older version when behaviour is replaced. PropertyDamage's library can run two systems on one sequence; Stratta has no second system yet.
- Seeded bugs in the code itself.

## 5. Recommendations

1. **Take PropertyDamage's method as this repository's methodology.** It has the converged shape, in this language, with the tooling already in use here.
2. **Treat the method and the library as separate commitments.** Commit to the method now. Commit to the library after it has run against the daemon on the operator's machine; if it does not fit, PropCheck or StreamData takes its place and nothing else changes.
3. **Write down what would make this decision wrong:** the library is abandoned or keeps breaking its interface; OpenSpec's ceremony costs more than it returns for one operator; a defect in use turns out to be of a kind none of this could catch. Any of the three reopens the question.
4. **Look again when Elixir gets typed signatures, and if a property-testing engine with the reach of Hegel gains an Elixir client.** Either would change the library choice, not the method.

## Sources

- The Claude Code team on verification, as reported: <https://news.lavx.hu/article/claude-code-team-details-how-it-verifies-agent-written-code>
- Verification designs in harnesses: <https://arxiv.org/abs/2610.34577>
- A case study in assuring agent-written software: <https://arxiv.org/abs/2610.08651>
- PBT-Bench: <https://arxiv.org/abs/2605.15229>
- The practitioner's scan: <https://github.com/eitri-edd/AI-PDLC/issues/122>
- Kiro's property tests: <https://kiro.dev/blog/general-availability/>
- Spec tools compared: <https://dev.to/willtorber/spec-kit-vs-bmad-vs-openspec-choosing-an-sdd-framework-in-2026-d3j>, <https://www.testmuai.com/blog/spec-driven-development-tools/>
- Antithesis, Hegel and Bombadil: <https://antithesis.com/docs/introduction/welcome/>
- Vericoding: <https://arxiv.org/abs/2509.22908>
- PropCheck: <https://github.com/alfert/propcheck>
- How agents use testing techniques (search excerpt only): <https://danluu.com/agentic-testing/>
