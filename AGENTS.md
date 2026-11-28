# Stratta: working rules

Rules for any agent (Claude Code, Codex, Gemini and others) and for people. The rules every repo shares are in [repo-template's README](https://github.com/markreveley/repo-template#the-rules); this file adds the repo's own. `CLAUDE.md` imports this file and adds nothing. It holds only the rules in force, with their reasons: no state, no next steps and no history (repo-template R32).

## Read first

1. `README.md`: what the repo is and the table of what is where.
2. `state.md` (what is true now) and `next.md` (what to do next, in order): where the last thread stopped. `/start` reads them; `/end` rewrites them. What to work on comes from `next.md`, not from reading other documents. Change `next.md` with `/update-next` (repo-template R30).
3. [`md/docs/design-commitments.md`](md/docs/design-commitments.md) before writing or changing a plan, and before reading a limit in a plan as a decision. `md/governance/` holds no governing document yet.
4. [`md/docs/operator.md`](md/docs/operator.md): notes for the person driving the agents. It says what a premise nobody stated looks like in a plan.
5. The tutorial, [`md/docs/tutorial/`](md/docs/tutorial/README.md): how the system works, from the process up. Each step in `next.md` links to the sections to read before working on it. Read those before starting the step.

## Where things are

- `core/`: the daemon. Threads, the timeline of events, git and worktrees, providers, storage, and the local control socket. No interface.
- `gui/`: the app, a Phoenix LiveView front end. It runs the core in the same node.
- `tui/`: `stratta`, the terminal client. It talks to the daemon over the socket.
- `md/`: every document about the repo. `md/README.md` lists the folders; each folder's README says what is in it here and links to repo-template's rules for it.
- `LOCAL.md` (git-ignored): names of private projects, local paths, and anything else that stays on one machine. This repo is public; name no private project in any tracked file.

## Working

- Commit and push straight to `main`, without asking (repo-template R29).
- Before changing a contract, check who reads it. `Stratta.API`'s operations and the socket's JSON frames are read by `tui/` and by any other client. The files under `~/.stratta` are read by every later version of the daemon, so a stored timeline has to keep loading.
- Tests: `(cd core && mix test)`, `(cd gui && mix test)`, `(cd tui && mix test)`. Run them before pushing. They need the versions `state.md` names. A session that cannot run them says so in `state.md`, and says what it ran instead.
- Threads are archived to direction with `/archive-thread`, not kept in this repo (repo-template R21).

## This repo's own rules

- Say what was run and what was only read, with the commit and the versions. The operator does not read the code, so a sentence that sounds checked and was not is the costliest kind of mistake here.
- A plan keeps `type: plan` and its `kind` (need, experiment or exploration) in its frontmatter, and has a section *Why this exists* that gives the evidence. A step in `next.md` carries its kind beside whose it is. The labels exist because a plan can run ahead of use and describe an idea as a need (design commitments, 3).
- A threshold, a stopping rule, an order or a "should not" in a plan is its drafter's suggestion, not a decision. If one is in the way, say so and ask; neither enforce it nor ignore it (design commitments, 4).
- The tutorial is kept true. A change to code it quotes or describes updates the section in the same commit, and a new step in `next.md` links to the sections it needs. Before pushing, run `python3 md/docs/tutorial/scripts/check_excerpts.py` and `python3 md/docs/tutorial/scripts/check_next.py`. After editing its `source/`, rebuild with `scripts/build.py` and run `scripts/check_site.py`; never edit the built pages. The tutorial is how the operator understands the system without reading the code, so a stale section misleads the reader it is for.
- A finding against the code or a document is an issue in `md/issues/`, with the commit it was seen at and whether it was run or read. A question for the operator is an `(operator)` step in `next.md` that links to an analysis written so that he can decide without reading the code.
