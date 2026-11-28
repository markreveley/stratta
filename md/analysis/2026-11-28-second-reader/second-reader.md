# A second reader on every change: can it be automatic, and which model?

**Date:** 2026-11-28

**Question.** PropertyDamage's method sends each change through a pull request with a second reader. The operator has adopted the method and asked: can the reader be automated, and would Claude Opus 5.5 do as well as a model from another maker (GPT-6 Astra, Kimi, Gemini)?

**Sources read.** The Claude Code documentation on its GitHub Action and on Code Review, as search excerpts. CRBugBench (arXiv 2610.13668), through its abstract page, for results by model. Song, *When Does a Second Model Help?* (arXiv 2610.01471), its abstract and excerpts. Two write-ups that compare those two studies. arXiv 2610.34577 on verification designs in agent harnesses. Five model comparisons from November 2026, as search excerpts. PropertyDamage's `.handoff/README.md` at `7bfa10a`.

**Method caveat.** Nothing was set up or run. Every source was read as a summary or an excerpt. The agent that wrote this is one of the models being compared, made by the maker of one side of the comparison. The model rankings quoted are from third parties and from makers' own tables, and they change monthly. How to run a reviewer from OpenAI, Moonshot or Google inside GitHub was not looked up.

---

## 1. The short answer

Yes, it can be automatic, and no person has to be in the loop. Opus 5.5 would do as well as any single alternative: the evidence found says a reviewer's strength and a fresh context matter, and that changing maker does not by itself make a better reviewer. What a second maker does add is different findings, so it is worth having as a second reviewer later, not as the first.

Start with the reviewer advisory, not blocking. None of the studies measured how often a reviewer is wrong.

> Added 2026-11-28. The gate that option B makes required now exists: CI runs it on
> every push ([what it runs and why](../../docs/ci.md)). It does not block; a push to
> `main` lands and the run reports a minute later.

## 2. What automating it means

- **The trigger.** Claude Code runs inside GitHub's workflows through an Action. It can review every new or updated pull request, and it can be given a prompt to run on any GitHub event. Anthropic also offers Code Review, which posts a review on every pull request without a workflow file.
- **Without a person.** A cloud session can open a pull request, wait for the checks, and merge when they pass. So "through a pull request" does not mean the operator approves each change. It means a change reaches `main` only after the gate has run on GitHub and a reviewer in a fresh context has read it.
- **Two details from the wider practice.** The reviewer's instructions are read from the base branch, so a change cannot edit the rules that judge it. And each review names the commit it read.
- **What it needs.** A secret for the model's API in the repository's settings, which only the operator can add, and money per review.

## 3. Which model

What was found, in the sources' own terms:

- **Reviewer strength.** On CRBugBench, bugs found in the top five comments, averaged over its two tracks: 71.9% for the strongest model tested (an Opus), with other models from two makers between about 33% and 56%. The benchmark's models are a generation behind today's. People plus the best agent together found 82.1%.
- **Fresh context.** In a comparison of seventeen verification designs, a separate critic in a fresh context gave the largest gains; a self-check by the author at the end gave little.
- **A different maker.** Song planted 150 errors in 30 artifacts. A top reviewer from another maker was not significantly different from the author's own model in a fresh session. The two found partly different errors (41% overlap). One review of each covered 56.7% of the planted errors against 42.7% for two reviews by the author's model. A weaker reviewer from another maker scored no higher than the same model.
- **Reconciled.** A write-up comparing the two studies concludes that mixing makers buys coverage because the findings differ, and that against two reviews by a strong reviewer that did not write the code, the mixed pair's gain was not significant.
- **Today's models.** In November's comparisons Opus 5.5, GPT-6.2 Astra, Kimi K3.1 Pro and Gemini 4 sit within a few points of each other on coding benchmarks, in an order that depends on the benchmark. None of those is a code-review benchmark.

So for one reviewer, any of the strongest models will do, and Opus 5.5 is the one that runs in the tooling this repository already uses. The case for another maker is as a second reviewer.

## 4. What is not known

- **How often a reviewer is wrong.** CRBugBench measures only what is found. A blocking reviewer that is often wrong would stop good changes.
- **Whether the code's author here is the reviewer's own family.** Stratta's sessions have used Claude models. Song's result is about exactly that case, and says a fresh session of the same model holds up.
- **Cost per review** on this repository.

## 5. The choice

**A. Keep pushing to `main`; review after the push.** An Action reads each push and files what it finds as an issue. Nothing blocks. Keeps repo-template R29 as it is.

**B. Pull requests; the gate is required, the reviewer advises.** A session opens a pull request; CI must pass before it merges; a reviewer in a fresh context comments. The session answers the comments or takes them to the operator. An exception to R29, declared in `AGENTS.md`.

**C. As B, with the reviewer required too.** A change does not merge until the reviewer has no open finding.

**D. As B or C, with a second reviewer from another maker.**

## 6. Recommendations

1. **B, now.** It makes the gate real: no change reaches `main` without the tests having run somewhere the coding session does not control. The reviewer starts as advice because its error rate is unmeasured.
2. **Opus 5.5 as the reviewer**, with its instructions read from the base branch.
3. **Move to C** when a month of its comments shows it is rarely wrong.
4. **Add D** if a defect gets past it that another model catches when asked afterwards. That is the evidence that would justify the second bill.

## Sources

- Claude Code's GitHub Action: <https://code.claude.com/docs/en/github-actions>
- CRBugBench: <https://arxiv.org/abs/2610.13668>
- When does a second model help: <https://arxiv.org/abs/2610.01471>
- The two studies compared: <https://astralab.co/insights/cross-model-code-review>, <https://www.howardism.dev/articles/code-review-agent-bug-detection>
- Verification designs in harnesses: <https://arxiv.org/abs/2610.34577>
- Model comparisons, November 2026: <https://www.respan.ai/articles/gemini-4-argon-vs-gpt-6-astra-vs-claude-opus-5-5>, <https://tech-insider.org/kimi-k3-1-pro-vs-claude-opus-5-5-vs-gpt-6-astra-2026/>
