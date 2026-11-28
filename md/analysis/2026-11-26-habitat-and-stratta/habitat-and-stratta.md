# Habitat and Stratta

**Date:** 2026-11-26

**Question.** How does Replit's Agent Habitat architecture read against this repository, under the operator's working assumption that agents are adversarial?

**Sources read.** Two Replit pages and search excerpts of a third, listed under [sources](#sources-and-how-they-were-read); Stratta's code at `419ebb9`.

**Method caveat.** The Replit pages were read through a tool that returns a summary, not in full. Nothing was run.

---

An analysis of Replit's Agent Habitat architecture read against this repository: where
the two already agree, where Habitat's tests land on gaps in Stratta, where they differ,
and what Habitat leaves open that Stratta is placed to look at.

It was drafted by an agent on 2026-11-26, from a thread with the operator
([where this came from](#where-this-came-from)). It is a reference, in the sense of
[design commitment](../../docs/design-commitments.md) 1: Habitat is named because a reader cannot
judge the comparison otherwise, and nothing in Stratta's code depends on it. The work
that follows from it is proposed in
[boundaries under an adversarial agent](../../plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md).

Stratta was read at `419ebb9`. Nothing here was run. Habitat was read through
summaries, not in full ([sources](#sources-and-how-they-were-read)).

- [What Habitat is](#what-habitat-is)
- [The assumption this document works under](#the-assumption-this-document-works-under)
- [The structural difference](#the-structural-difference-stratta-does-not-own-the-harness)
- [Stratta's planes, and what an agent can reach today](#strattas-planes-and-what-an-agent-can-reach-today)
- [Concern by concern](#concern-by-concern)
- [Where the plans already agree](#where-the-plans-already-agree)
- [Where Habitat's tests land on gaps](#where-habitats-tests-land-on-gaps)
- [Where they differ](#where-they-differ)
- [What Habitat leaves open](#what-habitat-leaves-open)
- [The conclusion the assumption forces](#the-conclusion-the-assumption-forces)
- [Cautions](#cautions)

## What Habitat is

Agent Habitat is Replit's name for a governed place where agents do a company's work:
they reach the company's systems and data, inside limits the company sets. It was
announced on 2026-10-28 with a white paper, *Agent Habitat Architecture*, by Luis Héctor
Chávez and Manish Mehta. The paper is a proposal. It has two parts: a reference
architecture, and a maturity scale for judging any agent environment, Replit's or
anyone else's.

In outline, and in this document's words:

- **The threat model includes the model.** Untrusted content, hostile users and
  compromised dependencies are in it, and so is the agent itself, which may probe for
  gaps. No control is allowed to rely on the agent behaving.
- **Three zones.** Trusted components issue identity, hold keys, keep the journal and
  broker every connection. The harness, which turns model output into tool calls, is
  half-trusted. The sandbox where code runs is untrusted and holds no credentials.
- **A broker is the only way out.** It adds a stored credential to a request it has
  authorised, so the agent never holds one.
- **Authority only narrows.** A run starts under a ceiling fixed before it begins.
  During the run permissions can shrink and cannot grow, and a subagent gets no more
  than its parent has at that moment. Filters that watch a run can refuse or escalate;
  they cannot grant.
- **A person approves what cannot be undone.** One approval covers one action, is drawn
  from what the action will really do, and arrives by a route the agent cannot write to.
- **Side effects are journaled** so that a resumed run does not repeat them, and a
  restart never widens what a run may do.
- **Stopping does not need the agent.** A violation stops the run, cuts its access and
  revokes what it held, without waiting for a person or for the agent to cooperate.
- **The record is kept out of the agent's reach**, so an audit never depends on the
  agent's own account.

The maturity scale has eleven tracks: sandbox isolation, network isolation, external
identity, policy, data flow, human approval, supply chain, durable execution,
containment, observation and workload identity. Each is rated 0 to 3, each level names
the evidence needed to claim it, and an environment is rated by its lowest track. The
levels are in the paper and are not repeated here.

Three things the paper does not say bear on this document. It names no storage
technology or tamper-evidence mechanism for its logs and journal. It does not say which
enforcement point catches a file written by a plain shell command inside the sandbox, or
what happens to a file's provenance once it is exported to a repository. And it does not
say how any of it applies to an agent running on a person's own machine; a companion
advisory recommends managed cloud environments as the default instead.

## The assumption this document works under

The operator's, stated in the thread on 2026-11-26 and lightly corrected for typing:

> We need to assume adversarial agents. Maybe not technically for most work on my
> computer, but my theory is that we need to draw the connection between the user/agent
> UI substrate/system and a habitat-like model. To do this, all concerns need to be
> accounted for in all planes. I still don't know if this is wrong or contrived, but I'm
> starting with this assumption.

Two things follow for how to read the rest.

- It is a working assumption and a theory, by the operator's own description. It is not
  a need observed in use. The plan that tests it is an experiment, and "this was
  contrived" is one of the answers it can return.
- It changes one earlier reading. [Authority for an answer](../../plans/2026-11-25-delegated-authority/delegated-authority.md)
  calls the risk of an agent answering another thread's request "modest" for one
  operator attending their own agents. Under this assumption it is not modest; it is
  the first thing an adversarial agent would do.

"Planes" below is this document's word, chosen by the drafting agent to give the
operator's sentence something to be checked against. The operator may want different
ones.

## The structural difference: Stratta does not own the harness

Habitat describes one company building every layer: the sandbox, the harness, the
broker, the journal, the approval screen. Stratta builds one of them. It is a control
plane over other people's agents: each thread starts a vendor's agent program (Claude
Code, Codex and the rest) through `Jido.Harness`, and that program is the harness in
Habitat's sense. It runs the model's tool calls itself, on the operator's machine, as
the operator.

| Habitat component | The nearest thing in Stratta | Whose it is |
| --- | --- | --- |
| Sandbox | None today. The agent's tools run on the host as the operator, in the project folder or a worktree. `Stratta.Environment` in [thread environments](../../plans/2026-11-25-thread-environments/thread-environments.md) would be the first. | The environment's |
| Harness | The agent program itself, reached over its protocol through a `Jido.Harness.Session`. Its `approval_mode` and `sandbox_mode` are options Stratta passes on and the agent program enforces. | The agent vendor's |
| Ceiling and tokens | For what the agent may do: the agent program's own modes. For who may answer a request: the grants in [authority for an answer](../../plans/2026-11-25-delegated-authority/delegated-authority.md). | Split |
| Broker | None. The daemon runs `git push` and `gh` on the host with the operator's own credentials. The brokered push in thread environments, Phase 3, is the first proposal of one. | Outside Stratta, by that plan |
| Journal | `Stratta.Timeline` and `Stratta.Store`: a transcript of what the agent reported, not a journal of side effects. [Decision records](../../plans/2026-11-25-decision-records/decision-records.md) add the answers. | Stratta's |
| Approval screen | The app, the viewer, the dashboard and `stratta approve`. | Stratta's |
| Identity issuer | None, on purpose: design commitment 2 keeps identity outside. | Outside Stratta |
| Out-of-reach log | None. [Traces and measures](../../plans/2026-11-25-decision-telemetry/decision-telemetry.md) has an exporter that could feed one. | Outside Stratta |

Two consequences.

First, a permission request reaching Stratta is the agent program reporting what it is
about to do. Stratta sees what that program chooses to send. An agent running in an
auto-approve mode, or doing its work through a shell command it was allowed to run,
produces no request at all.

Second, the grants in the delegated-authority plan and the permissions in Habitat answer
different questions. Habitat's limit what an agent may do. Stratta's limit who may
answer when an agent asks. Stratta has no control of its own over the first; it has the
agent program's modes, and, if a thread runs in an environment, that environment's
walls.

What Stratta does own is the part Habitat says least about: the screen where a person
sees a request and answers it, the route the answer travels, and the record of it.

## Stratta's planes, and what an agent can reach today

Every agent Stratta starts runs as the operator. So does every shell command it runs.
Facts from the code at `419ebb9`:

| Plane | What is in it | What a process running as the operator can do |
| --- | --- | --- |
| **Execution** | The agent process and its files: the project folder, or a worktree under `.stratta/worktrees/`. | Read and write anything the operator can, in the home directory and beyond. A worktree separates threads from each other by convention only. |
| **Control** | The Unix socket `~/.stratta/stratta.sock`, mode 0600, and the operations of `Stratta.API`. | Call any operation. `thread.approve` answers any thread's request; `thread.send` puts a message into any thread; `thread.ship` commits, pushes and opens a pull request. The socket does not ask who is calling. |
| **Surface** | The app on `127.0.0.1:4001`, with no login; the viewer and dashboard; the status reports (OSC 7501, OSC 9;4); the opener and the status hook. | Connect to the app and answer a request with no browser. Put text on every surface: a request's title, a message, a diff, a thread's title in a status report. |
| **Record** | `~/.stratta/state.json` and `threads/<id>.json`, rewritten whole by the daemon. Decision records are planned for the same directory. | Rewrite or delete any of it. |
| **Configuration** | Instruction files (`CLAUDE.md`, `AGENTS.md`); the agent program's settings and hooks; git hooks; `STRATTA_OPENER` and `STRATTA_STATUS_HOOK`, which are shell commands read from the environment; the rule set planned for the data directory. | Write all of them. The opener and status hook are set wherever the operator's shell is configured, which is a file. A worktree shares its repository's git hooks. |
| **Outside** | Each agent program's own login, kept in the home directory; the operator's git and GitHub credentials; the network. | Read the logins and credentials; reach any host. |

Three details from the code, each small and each on the surface plane:

- **A request is drawn from the agent's wording.** `Stratta.Timeline` keeps a request's
  `title`, `tool_kind`, `options` and `diffs`, all as the agent program sent them. It
  does not keep the raw input for a request, though it does for a tool call. The app
  and the viewer both show the title in bold beside the approve control.
- **Agent text is escaped but not uniformly cleaned.** The app HTML-escapes agent text
  and makes links only from `http` and `https` addresses, though a link's label is the
  agent's. In the terminal client, `Stratta.TUI.Status.clean/2` removes C0 and C1
  control characters and bidirectional overrides; `Stratta.TUI.Render.fit/2` replaces
  C0 controls only. Whether every path that draws agent text goes through either was
  not checked.
- **The daemon runs the repository's hooks.** `Stratta.Git.commit/3` runs `git add -A`
  and `git commit`, and `push/3` runs `git push`, with hooks enabled. A hook the agent
  wrote is run by the daemon when the operator ships.

## Concern by concern

Habitat's concerns down the side, in this document's grouping. "Planned" names the plan
that touches it, not a claim that the plan is sufficient.

| Concern | Stratta today | Planned | What is left |
| --- | --- | --- | --- |
| Isolation of execution | None of its own. Worktrees separate threads' files. | [Thread environments](../../plans/2026-11-25-thread-environments/thread-environments.md), unscheduled. | Everything, until a thread runs somewhere else. |
| Network | Unrestricted. | Nothing. | An environment's job, not the daemon's. |
| Credentials | Stores none. The agent program's login and the operator's git credentials are readable by the agent. | Brokered push, thread environments Phase 3. | The agent program's own login: Phase 0 of that plan. |
| What the agent may do | The agent program's modes, passed through. | [Policy as actions](../../plans/2026-11-25-policy-as-actions/policy-as-actions.md) answers requests by rule; it does not limit an agent that does not ask. | A ceiling Stratta enforces itself. Only an environment can give one. |
| Who may answer | Anyone who can open the socket or reach the app. | [Authority for an answer](../../plans/2026-11-25-delegated-authority/delegated-authority.md): grants, narrowing that only weakens. Steps 6, 10 and 17. | The grant's secret is in the data directory, which the agent can read. |
| Approval by a person | Per request, by default. Drawn from the agent's title and diff. | [Choice requests](../../plans/2026-11-26-choice-requests/choice-requests.md) adds option labels, also the agent's text. | Drawing from the real parameters; checking afterwards that what was done is what was asked. |
| Triggers | Not recorded. A message's sender is not kept, and one thread can send to another. | Decision records keep who answered. | Who or what started each turn. |
| Instruction and hook files | No special handling. | Nothing. Pane threads rely on hooks and do not consider an agent editing them. | All of it. |
| Journal and recovery | A transcript, saved on a debounce. A commit, push or pull request leaves a notice in it afterwards. | Decision records. | A record written before a side effect as well as after, so that an interrupted ship is not repeated or lost. |
| Stopping | `thread.interrupt` asks the agent's session to stop. Step 19 of `next.md` suspects that deleting a thread or stopping the daemon may leave the session open. | Step 19's tests. | A stop that does not depend on the agent, and that withdraws what it held. |
| Record out of reach | Files the agent can rewrite. | Decision records, append-only, in the same directory. [Traces and measures](../../plans/2026-11-25-decision-telemetry/decision-telemetry.md) can export. | Somewhere the agent cannot write. |
| Supply chain | Nothing. The agent program installs what it likes. | Nothing. | An environment's job and the agent program's. |
| Identity of workloads | The operator's, borrowed by every agent. | Design commitment 2: identity is configured in. | Outside Stratta by its own rule. |

## Where the plans already agree

Several plans here reach Habitat's conclusions in nearly its words, and were written
without it.

- **Narrowing.** "A grant may only produce a weaker grant", enforced in the behaviour
  and tested as a property, with Biscuit named as the token. Habitat's rule that
  authority only shrinks within a run, with each narrowing written into the token, is
  the same idea.
- **Identity is not authority.** Design commitment 2 separates "may this be done" from
  "who did it, provably". Habitat keeps the same two apart.
- **A broker that never hands over the secret.** Thread environments describes pushing
  as "a narrow operation it may ask for", brokered by something that holds the
  credential. Its list of what Mjolnir's egress endpoint lacks (a limit on the
  operation, an approval step, protection against a repeated effect, a record) is close
  to what Habitat asks of a broker, an approval and a journal together.
- **Restoring is not a way to gain authority.** That plan's question about two restores
  of one checkpoint being two claimants to one identity is Habitat's rule that a restart
  never widens permissions.
- **A failure never approves.** The policy plan's "default is ask" and the pane-threads
  plan's "a hook that fails must not approve" match Habitat's rule that an unreachable
  policy check denies.
- **Rules kept away from the agent.** The policy plan keeps its rule set in the data
  directory because "a rule set that an agent can edit is a rule set an agent can
  widen". The reasoning is Habitat's. The data directory is still the agent's to write.
- **Custody, not truth.** The authority plan's statement that a signature shows who
  answered and not whether the agent reasoned honestly is the same line Habitat draws
  when it puts model alignment out of scope.

## Where Habitat's tests land on gaps

Four, in the order the thread reached them.

1. **The route an answer travels.** Habitat wants approvals to arrive by a route the
   agent cannot write to. In Stratta the agent can write to both routes: the socket and
   the app. This is already known here: it is Phase 0 of the authority plan, Design 7
   and Phase 3 of the composed-surfaces plan, and steps 6 and 10 of `next.md`. Habitat
   confirms the reading and adds nothing to it.
2. **Where the record lives.** Habitat wants every decision logged where the agent
   cannot write. The decision-records plan stores them append-only in `~/.stratta`.
   Append-only is a property of how the daemon writes, not of the file: the agent can
   rewrite it. No plan mentions this.
3. **Instruction, configuration and hook files.** Habitat wants a write to one approved
   or held aside until a person has looked. Stratta treats such a write like any other.
   The pane-threads plan is the sharpest case, because its control is a hook.
4. **What is shown is what will be done.** Habitat wants an approval drawn from the
   action's real parameters and not from the agent's description. Stratta shows the
   agent's title and the agent's diff, and does not check afterwards that the file
   matches.

## Where they differ

- **Rules that grant.** In the thread this was first put too strongly, as "Habitat's
  rules can deny but never grant". That is true of its filters, which watch a run. Its
  ceiling does grant, and is set before the run by someone authorised to. So a rule set
  the operator writes beforehand is a ceiling in Habitat's terms, and consistent with
  it. The differences are narrower: "always allow this", which widens the rule set in
  the middle of a thread, where Habitat allows a ceiling to be raised only between
  runs; a rule set stored where the agent can write; and
  [an agent as an approver](../../plans/2026-11-25-agent-approver/agent-approver.md), which is unscheduled, and which
  would have something other than a person approve.
- **The operator's own machine.** Habitat's answer is to move the work to a managed
  environment. Stratta's premise is the opposite: the operator's machine, the
  operator's terminal, the operator's subscriptions.
- **One operator.** Habitat is built around organisations, tenants and principals.
  Stratta has one person and puts teams and roles out of scope.
- **Requests as information.** Habitat treats an approval as a gate on actions that
  cannot be undone. The operator's report of 2026-11-26 is that requests are also how
  he sees what an agent is about to do. Nothing in Habitat contradicts that, and
  nothing in it values it either.

Not taken from Habitat, whatever else is: its log formats, its tenant model, and its
score.

## What Habitat leaves open

Three places where the paper stops and Stratta's own subject begins. These are the
drafting agent's reading.

- **The approval surface.** The paper requires a trusted screen and says little about
  one: how a request is drawn so that agent text cannot pass for a control, what a
  person is shown when the agent's description and its parameters disagree, how several
  panes with different authority are told apart, what a status report may carry. The
  [composed-surfaces](../../plans/2026-11-26-composed-surfaces/composed-surfaces.md) plan's Design 7, a view that holds
  the authority it needs and no more, is already an answer to a question the paper does
  not ask. This is the connection the operator's theory proposes: the surface as one of
  the planes a habitat has to account for.
- **The exit.** The paper says files carry the provenance of the run that wrote them,
  and that executables are flagged before anything outside the sandbox runs them. It
  does not say how, or what survives a push. Stratta already has an exit: the diff
  against the thread's base commit, reviewed before shipping. If a thread's files live
  behind a wall, that diff is the only way a file reaches the operator, and a check
  there cannot be gone around.
- **The local machine.** The paper does not cover it. Whether the cheapest second zone
  on one machine (another user account, a container, a small virtual machine) is enough
  to make any of this hold is not answered anywhere this document's sources reach.

## The conclusion the assumption forces

If the agent is adversarial and runs as the operator, no control in any plane holds.
The socket's permissions, a grant's secret, an append-only file, a list of protected
paths, the app's login: each is a file or a port the agent can reach. The paper's own
phrase for the posture is to "assume it will find any gap".

So accounting for every concern in every plane comes down to one move and then many
small ones. The move: the agent runs in a different zone from the daemon, the record
and the surfaces. The small ones: what crosses between the zones, in each direction,
and who checks it.

That would make [thread environments](../../plans/2026-11-25-thread-environments/thread-environments.md), which `state.md`
lists as unscheduled because nothing depends on it, the thing everything else under this
assumption depends on. Whether to reorder is the operator's decision. The plan beside
this document does not assume it; it measures first.

Without that move, the same controls still do something. They hold against an agent
that is mistaken, and against one that has been steered by something it read. Habitat's
scale makes the same distinction between limiting accidents, limiting injected
instructions, and limiting an agent that is looking for gaps. Which of those the
operator is building for, thread by thread, is his to say.

## Cautions

From [operator.md](../../docs/operator.md), applied to this document.

- **A premise.** The adversarial assumption is the operator's, stated once, and marked
  by him as uncertain. A later agent should not read it as settled.
- **A number with a target.** Habitat's scale is eleven numbers, each with a line to
  reach. This document does not score Stratta against it, on purpose. A default thread
  would sit at or near the bottom of most tracks, and that says more about where the
  scale was drawn (a company's cloud) than about what to build next.
- **Plans that justify each other.** Agreement between Habitat and plans written here
  is not evidence that either is right. Both could share a mistake.
- **Plans ahead of use.** `state.md` says nothing in `next.md` is built and no day of
  real work is on record. This is one more document on that pile.

## Sources and how they were read

- *Agent Habitat Architecture*, Luis Héctor Chávez and Manish Mehta, Replit, 2026-10-28:
  <https://frontier.replit.com/agent-habitat-architecture/>
- *Security advisory: Make managed cloud environments the default for AI agents*,
  Replit: <https://frontier.replit.com/managed-cloud-environments-for-ai-agents/>
- *Replit's Architecture Behind Secure Agent Work*, Replit:
  <https://replit.com/blog/architecture-behind-secure-agent-work>, from search
  excerpts only.

The first two were read on 2026-11-26 through a tool that fetches a page and returns a
summary of it in answer to a question. The drafting agent did not see their full text.
Everything said about Habitat here is that agent's paraphrase of those summaries, and
the one phrase in quotation marks came back from the tool and was not checked against
the page. Anyone relying on a detail should read the paper.

## Where this came from

A thread of 2026-11-26 between the operator and Claude. It began with the question of
what a Replit habitat is, went on to an examination of Habitat against this repository,
and ended with the operator asking for this document and for a plan. Unless the operator
exports it, it is not readable by anyone else. What it produced:

- this document;
- [boundaries under an adversarial agent](../../plans/2026-11-26-adversarial-boundaries/adversarial-boundaries.md), a plan;
- the operator's working assumption, quoted above;
- one correction of the agent by the agent, under [where they differ](#where-they-differ).

It changed nothing in `next.md` or `state.md`.
