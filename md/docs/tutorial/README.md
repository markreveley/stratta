# Stratta's architecture, from the process up

A tutorial on the concepts needed to read [`next.md`](../../../next.md) and the plans in
[`md/plans/`](../../plans/README.md) of this repository: what the system is today, the OTP it
is built from, the agent protocols at its edge, Jido, and the control-plane ideas the twenty-one plans
introduce (decision records, traces, policy, grants, one registry of operations, code mode, claims,
two kinds of graph, environments). It ends by reading `next.md` as a dependency graph, step by step.

**To read it, open `index.html`.** No server, build step or network is needed. `single.html` is the
same text on one page. On GitHub, `source/tutorial.md` is readable as it stands, without the diagrams.

It describes Stratta at commit `a7c451f` (25 November 2026). The list of plans in section 4 and all of Part 7 follow `next.md` as reordered on 26 November 2026, when the operator chose to build Stratta first as a guest in a host terminal, with the app taken apart into views. Sections 25 and 34 and the end of section 12 follow two plans added later that day, on ids and a log of events and on graphs. Both are as of Stratta commit `2846650`, which also holds a repair to how timeline items get their ids; section 12 shows it. Part 7's step numbers are looked up in `next.md` when the pages are built; the eleven newest steps and the two newest plans are named, not described. Plans are named by their current paths under `md/plans/`. Written for a reader who has done an
introductory Elixir course, as far as a first GenServer, and knows how the BEAM holds data in memory.

Each step in `next.md` links to the sections to read before working on it.

## Shape

The form: a
start page, seven parts with sections numbered straight through (1 to 40), every term defined in
**bold** where it first appears, and a glossary that names the section introducing each term.

| Page | What it covers |
|---|---|
| `index.html` | What the tutorial is, what it assumes, and how to read it |
| `part1.html` | The system today; one permission request followed end to end; the plans in four groups |
| `part2.html` | Processes, GenServer, links and monitors, supervisors, registries, tasks |
| `part3.html` | State as a fold over events; what survives a restart; PubSub; snapshots and coalescing |
| `part4.html` | The control socket; `Stratta.API`; ports and the process helper; ACP; hooks; terminals |
| `part5.html` | Behaviours; Jido version 3; plugins (the plans' "skills"); Route A and Route B; flows, waits and durable runs |
| `part6.html` | Decision records, traces, policy, authority, the reviewer, the operation registry, code mode, claims and context, the record graph and the work graph, files, hosts and environments |
| `part7.html` | `next.md` as a graph; where each step's reading list is kept; what waits; the labs; what the reading turned up |
| `glossary.html` | 140 terms, and the Sources section |

## The labs

Seven single-file Elixir scripts, each a miniature of one part of Stratta, with inline ExUnit tests:

```sh
elixir exercises/01_thread_server.exs     # fails until you fill in the stubs
elixir solutions/01_thread_server.exs     # the same tests, solved
```

| Lab | A miniature of |
|---|---|
| `01_thread_server` | `Stratta.ThreadServer`: one process owning requests, a debounced save |
| `02_supervision` | `ThreadSupervisor` and `ThreadRegistry`: start on demand, find by name |
| `03_timeline` | `Stratta.Timeline`: a fold over events, request letters, evidence as ids |
| `04_pubsub` | topics on a Registry; the socket's coalescer |
| `05_socket` | `Stratta.Socket` and its client: frames, ids, pushes |
| `06_port` | an agent behind a port, holding its turn on a permission request (needs `sh`) |
| `07_authority` | planned: rules, a local grant with narrowing, an answer that names both |

`exercises/` and `solutions/` are generated from one master per lab in `source/labs/`. Edit the
masters and run `python3 scripts/make_labs.py`.

## What is checked, and how

- **Stratta's code excerpts are compared with the repository.** `scripts/check_excerpts.py` finds
  each excerpt titled "Stratta: path" in the named file of a Stratta checkout, as consecutive lines.
  Result: `research/verify/stratta-excerpts.txt`, which names the commit of its last run. With no argument it
  checks this repository.
- **`next.md` and the tutorial are checked against each other.** `scripts/check_next.py` checks that every
  section `next.md` links to exists under that title, that every step the source mentions by key is
  found in `next.md`, and that the pages were built with the step numbers `next.md` has now.
- **Step numbers are not written down here.** The source names a step by a key, `[[step:decision-records]]`,
  and `scripts/steps.py` looks its number up in `next.md` when the pages and the diagram are built.
  `source/steps.txt` holds the keys. When a step is added or moved, rebuild; nothing else changes.
- **Lab code on the pages is never retyped.** `scripts/build.py` cuts it from `solutions/`, and cuts
  the terminal output from the transcripts.
- **The labs were run.** `scripts/run_labs.sh` requires every solution to pass with no warnings and
  every exercise file to compile and fail. Transcripts: `research/verify/labs-solutions.txt` and
  `labs-exercises.txt` (45 tests; Elixir 1.14.0 on Erlang/OTP 25).
- **The pages are checked.** `scripts/check_site.py` checks every internal link and anchor, that each
  glossary term is in bold in the section the glossary names, and that nothing but the font links
  leaves the page.
- **Claims about Jido, Jido.Harness, the BEAM Book and Phoenix.PubSub were read from clones** at
  named commits. `research/source-checks.md` maps claims to sources.
- **One of Stratta's modules was run by itself.** `scripts/check_timeline_ids.sh` loads
  `core/lib/stratta/timeline.ex` from a Stratta checkout, unchanged, and runs it across two lifetimes
  of the virtual machine. It exits non-zero if an item id repeats after a restart. Results, both on
  Elixir 1.14.0 with Erlang/OTP 25, older than Stratta requires: `research/verify/timeline-ids.txt`,
  which passes against Stratta `2846650`, and `research/verify/timeline-ids-before.txt`, the same
  check failing against `f102429`, the commit before Stratta's repair.
- **Not checked:** Stratta itself was not run (it needs Elixir 1.19 and OTP 28, which the authoring
  environment could not install), so six of section 40's seven observations are from reading. Jido's
  flows and durable runs (section 25) were read and not built. The ACP and hooks
  pages were read through a retrieval tool, not directly. See the Sources section and the last two steps of `next.md`.

## Layout

```
index.html, part1.html … part7.html, glossary.html   the pages
single.html                                          the same text on one page, self-contained
assets/        style.css, site.js, diagrams/ (7 SVG)
source/        tutorial.md, glossary.md, sources.md  the text: edit these, not the HTML
               steps.txt                             a key for each step of next.md the text mentions
               labs/                                 the lab masters
exercises/     the labs with stubs                   generated
solutions/     the labs solved                       generated
scripts/       build.py, check_site.py, check_excerpts.py, check_next.py, steps.py, make_diagrams.py, svg.py,
               make_labs.py, run_labs.sh, check_timeline_ids.sh, timeline_ids/
research/      source-checks.md, build-stats.json, verify/ (transcripts)
```

## Rebuilding

From this folder:

```
python3 scripts/make_labs.py                    # only if a lab master changed
sh scripts/run_labs.sh                          # needs elixir; rewrites the lab transcripts
python3 scripts/make_diagrams.py                # if a diagram changed, or a step in next.md was added or moved
python3 scripts/check_excerpts.py               # the excerpts against this repository's code
python3 scripts/check_next.py                   # next.md and the tutorial against each other; run after build.py
sh scripts/check_timeline_ids.sh                # needs elixir; fails if an item id repeats after a restart
python3 scripts/build.py                        # needs: pip install markdown
python3 scripts/check_site.py
```

When the code changes, `check_excerpts.py` shows which excerpts no longer match. The plans' *What happens today* sections age the same way, and section 37 says how to
re-check them.

## Authorship

Written by an AI model (Claude) on 25 November 2026, with sections 25 and 34 added the next day, from
the Stratta repository and the references named in the Sources section. Stratta's code and plans are quoted as they stood at commit `a7c451f`. It was written in another repository and moved into this one on 27 November 2026, when the table of steps in section 37 was replaced by links from `next.md`.
