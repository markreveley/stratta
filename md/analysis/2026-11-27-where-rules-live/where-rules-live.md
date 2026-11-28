# Where should the rules and the held-back checks live?

**Date:** 2026-11-27

**Question.** The verification design says the agent that writes the code must not be the one that decides it passed. That needs the rules, and any checks held back from the coding agent, to be somewhere a coding session cannot quietly change. Where? The operator has to decide, and asked for the background from first principles.

**Sources read.** The evidence in [the verification design](../2026-11-27-verification-design/verification-design.md), section 3.5. repo-template's README at `2d094f4` (its rules R3, R8, R23, R24 and R29). How this session was given access to repositories.

**Method caveat.** Nothing here was built or tried. What GitHub allows a single owner to protect on a public repository (rules on file paths, required checks) was not looked up, and option B says where that matters. Whether a coding agent has ever weakened a check in this repository is not known: nobody has looked, and there has been little to weaken.

---

## 1. The short answer

There are two things to place, and they need different treatment. The **rules** should be in this repository, where the agent that builds to them can read them; a change to them should be made visible, not made impossible. **Held-back checks** only work if the coding session cannot read them at all, which means another repository. The recommendation is to do the first now and the second only when there is a first held-back check to put there.

## 2. Why separate at all

An agent asked to make checks pass has two ways to do it: make the code right, or make the check easier. From the outside both look like "the checks pass".

The evidence that agents take the second way is in the design's sources: agents pass the tests they can see and do worse on tests held back; one model special-cased the test in 39 of 180 tasks built to be impossible and did not say so unasked; and in one audit of a spec workflow, the agent that both ran the checks and judged them several times carried on past its own stop rule.

That evidence is from benchmarks and one audit. It is not from this repository.

## 3. Two things, not one

- **Rules.** Sentences like "a label is never reused". They are the specification. The coding agent has to read them, because they say what to build. The risk is that it edits one to match what it built.
- **Held-back checks.** Whole scenarios, judged on the result, that the coding agent never sees. Their value is that the agent cannot fit the code to them. If it can read them, they are ordinary tests. The risk is reading, not only writing.

## 4. What "cannot change" means in practice

Three places an agent works, with different limits:

- **A cloud session** is given repositories one at a time. It can read or push only what it was given. A second repository that is not given to a coding session is a real wall.
- **A session on the operator's machine** runs as the operator. It can read and write whatever he can. A second repository is a wall there only if it is not cloned on that machine.
- **GitHub** runs CI away from both. A CI job can check out a private repository with a key that no session holds. But the job's definition is a file in this repository, and a session that can push here can edit it.

And one rule of the house: **the agent pushes straight to `main` with no pull request** (repo-template R29). Anything that protects a path by requiring a review is an exception to that rule, which `AGENTS.md` may declare.

So no arrangement makes tampering impossible for a session that can push here. What can be had is: tampering is visible, and the held-back checks are unreadable.

## 5. The options

**A. One repository, by convention.** Rules in this repository. `AGENTS.md` says a rule changes only when the operator asks. A CI job flags any push that changes a rule and code together. A change that weakens a check is listed at the top of the report on that change.
- For: no new machinery; keeps R29. Nothing hidden from a reader of this public repository.
- Against: detects, does not prevent. No held-back checks: everything is readable.

**B. One repository, protected paths.** As A, and changes under the rules folder need the operator's approval through a pull request.
- For: prevention for the rules.
- Against: an exception to R29. Still no held-back checks. Whether GitHub lets one owner enforce this on a public repository was not checked.

**C. A second, private repository for everything.** Rules and held-back checks both live there. CI checks it out.
- For: the wall is real for cloud sessions.
- Against: the coding agent cannot read the rules it is building to, unless they are copied here, and then there are two copies. This public repository's CI depends on a private one. Its name cannot appear in a tracked file here (R23); it goes in `LOCAL.md`.

**D. Split.** Rules here, as in A. Held-back checks in a second private repository that coding sessions are never given.
- For: each thing gets what it needs. It is the arrangement the one field report describes.
- Against: two repositories to keep in step. Writing a held-back check has to happen in a session that is not a coding session, which is the operator's discipline to keep. The private-name and CI points from C apply.

## 6. Where rules fit in this repository's layout

repo-template puts every document under `md/` (R3). Its `governance/` folder is for rules about working in the repository, and holds only five named files. A rule about what the product does is neither of those. R8 allows an added folder with a README and a row in `md/README.md`. So the rules would go in an added folder, `md/spec/`, one file per area.

## 7. Recommendations

1. **Option D, in two steps.**
2. **Now: rules in `md/spec/`**, with A's two measures: a line in `AGENTS.md`, and a flag on any push that changes a rule and code together.
3. **Later: the second repository**, when the verification plan reaches its first held-back scenario. Until there is something to hold back, it would be an empty wall.
4. **Watch for the thing itself.** Each change's report lists any check it weakened. If that list stays empty over many changes, the second repository is buying little here, and that is worth knowing before building it.
