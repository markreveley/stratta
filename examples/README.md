# Examples

Reference implementations of Unix Agentics patterns.

## Official Implementations

| Project | Description | Link |
|---------|-------------|------|
| **agen** | Core CLI — the Unix-native AI agent | [github.com/markreveley/agen](https://github.com/markreveley/agen) |
| **agen-skills** | Workflow scripts (ship, review) | [github.com/markreveley/agen-skills](https://github.com/markreveley/agen-skills) |
| **tourlab** | Domain example — tour advancing | [github.com/markreveley/tourlab](https://github.com/markreveley/tourlab) |

## Quick Examples

### Basic Pipeline

```bash
cat error.log | agen "diagnose this error" | agen "suggest a fix"
```

### Code Review

```bash
git diff | agen --system=REVIEWER.md "review these changes"
```

### Natural Language Shell

```bash
shell find all python files modified this week
# Stages the command for review before execution
```

### RAG-Powered Drafting

```bash
# Index your documents (one-time)
llm embed-multi docs --files *.md -m 3-small

# Draft with context
query="How do I configure authentication?"
similar=$(llm similar docs -c "$query" -n 3 | jq -r '.id')
cat $similar | agen "Answer this question based on the docs: $query"
```

## Creating Your Own

See [PATTERNS.md](../PATTERNS.md) for common patterns and best practices.

The key principle: **the shell orchestrates, agen is one tool among many**.
