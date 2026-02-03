# Stratta

**Unix Agentics** — the practice of building AI agents as composable Unix tools.

```bash
cat error.log | agen "diagnose" | agen "suggest fix" > recommendations.md
```

## The Thesis

The terminal is a 50-year-old prototype of an agentic interface. The Unix philosophy — small tools, composition, text as universal interface — isn't just applicable to agent architectures. It's *optimal* for them.

When Anthropic says "simple, composable patterns," when Vercel says "just filesystems and bash," when Fly.io says "agents want computers, not sandboxes" — they're all pointing at Unix without always naming it.

## Vision B: Agent in the Shell

The dominant paradigm (Vision A) puts the agent in control: you live inside Claude Code or ChatGPT, the agent orchestrates tools, sessions are ephemeral.

Unix Agentics inverts this (Vision B): the agent is one tool among many. The shell orchestrates. Agents compose in pipelines. State lives in files. Git is the audit trail.

```
Vision A: User → Agent → [tools]     # Agent orchestrates
Vision B: User → Shell → [agent | grep | agent | sort]  # Shell orchestrates
```

## Quick Start

```bash
# Install the stack
./setup.sh

# Use agen
agen "Explain Unix pipes"
echo "hello" | agen "translate to French"

# Natural language → shell command
shell list all files over 100mb
# Stages: find . -size +100M (you review, then Enter to run)
```

## Documentation

| Document | Description |
|----------|-------------|
| [PHILOSOPHY.md](PHILOSOPHY.md) | The full thesis — conviction anchor |
| [GETTING_STARTED.md](GETTING_STARTED.md) | Practitioner's guide |
| [TOOLS.md](TOOLS.md) | Recommended stack |
| [PATTERNS.md](PATTERNS.md) | Common patterns (RAG, drafting, etc.) |

## Implementations

| Project | Description |
|---------|-------------|
| [agen](https://github.com/markreveley/agen) | Core CLI — Unix-native AI agent |
| [agen-skills](https://github.com/markreveley/agen-skills) | Workflow scripts (ship, review) |
| [tourlab](https://github.com/markreveley/tourlab) | Domain example — tour advancing |

## Principles

1. **Agents want computers, not containers** — Persistent storage, no arbitrary death
2. **Filesystem as context substrate** — Files, not databases
3. **Agents solve non-coding problems by writing code** — Prefer bash over tool-calling
4. **Context engineering > prompt engineering** — Think in environments, not prompts
5. **Transparency over abstraction** — If you can't `cat` it, be suspicious
6. **Simple beats clever** — One loop that works beats complex orchestration
7. **Observation enables iteration** — Debug with grep, not dashboards

## Why "Stratta"?

Stratta is the umbrella for Unix Agentics — the philosophy, the tools, the patterns. The name evokes *strata* (layers) and *strategy* — building agents through layered composition rather than monolithic frameworks.

## License

MIT
