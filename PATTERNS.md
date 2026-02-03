# Unix Agentics Patterns

Common patterns for building with agen and the Unix Agentics stack.

## Pattern 1: Basic Pipeline

Chain agents in Unix pipelines.

```bash
cat data.csv | agen "summarize" | agen "format as markdown" > summary.md
```

**When to use:** Simple transformations, multi-step processing.

## Pattern 2: System Prompt Files

Create reusable agent personas with system prompt files.

```bash
# Create the persona
cat > REVIEWER.md << 'EOF'
You are a senior code reviewer.
Focus on: bugs, security issues, performance problems.
Skip: style nitpicks, formatting.
Be concise. Use bullet points.
EOF

# Use it
git diff | agen --system=REVIEWER.md "review these changes"
```

**When to use:** Domain-specific agents, consistent behavior across invocations.

## Pattern 3: Natural Language to Shell

Stage shell commands from natural language descriptions.

```bash
# Add to ~/.zshrc
shell() {
  print -z "$(agen "Convert to a shell command. Output ONLY the raw command. No markdown, no code blocks, no explanation, no backticks. Just the command itself: $*")"
}
```

Usage:

```bash
shell find all log files larger than 10mb modified this week
# Stages: find . -name "*.log" -size +10M -mtime -7
# You review, edit if needed, then press Enter
```

**When to use:** Learning commands, complex flag combinations, one-off operations.

## Pattern 4: Conditional Logic

Use agent output in shell conditionals.

```bash
#!/usr/bin/env bash
diff=$(git diff --cached)
result=$(echo "$diff" | agen "Does this change the public API? Reply YES or NO only.")

if [[ "$result" == "YES" ]]; then
  echo "API change detected — update documentation"
  exit 1
fi
```

**When to use:** Quality gates, pre-commit hooks, CI/CD pipelines.

## Pattern 5: RAG with Embeddings

Use llm's embedding support for retrieval-augmented generation.

### Setup (one-time)

```bash
# Index your documents
llm embed-multi emails --files state/emails/*.md -m 3-small
```

### Retrieval + Generation

```bash
#!/usr/bin/env bash
# draft - Generate content with relevant context

query="$*"

# Find similar documents
similar=$(llm similar emails -c "$query" -n 3 2>/dev/null | jq -r '.id' || true)

# Build context
{
  echo "## Reference Documents"
  for doc in $similar; do
    [[ -f "state/emails/$doc" ]] && cat "state/emails/$doc"
  done
  echo "---"
  echo "## Request"
  echo "$query"
} | agen "Draft a response based on the reference documents."
```

**When to use:** Email drafting, documentation, any task benefiting from similar examples.

## Pattern 6: Style Guide Extraction

Generate a style guide from existing content, then use it for new content.

```bash
# Extract style from existing emails
cat state/emails/*.md | agen "Analyze these emails. Extract:
1. Tone (formal/casual)
2. Common phrases and openers
3. How questions are structured
4. Signature conventions
Output as a concise style guide." > state/EMAIL_STYLE.md

# Use the style guide
cat state/EMAIL_STYLE.md | agen "Write an email requesting load-in time, following this style"
```

**When to use:** Maintaining voice consistency, onboarding, brand compliance.

## Pattern 7: Incremental Processing

Process files one at a time with state accumulation.

```bash
#!/usr/bin/env bash
# Process each file, accumulate results

summary=""
for file in docs/*.md; do
  result=$(cat "$file" | agen "Summarize in one sentence")
  summary="$summary\n- $(basename "$file"): $result"
done

echo -e "$summary" | agen "Create an overview from these summaries"
```

**When to use:** Large document sets, progressive summarization.

## Pattern 8: Evidence Protocol

For applications requiring auditability (like tourlab).

```bash
# state/dates/2026-03-15-boston.md

---
load_in_time: 14:00
---

## Evidence Log

### 2026-02-15 — load_in_time set to 14:00
Source: emails/boston-production-thread.md
Quote: "Load in will be at 2pm, please have trucks at loading dock by 1:45"
Changed: `load_in_time: null` → `load_in_time: 14:00`
```

The agent is instructed (via SYSTEM.md) to never change a field without logging evidence.

**When to use:** Compliance, auditable workflows, legal/financial applications.

## Pattern 9: Skill Composition

Skills (shell scripts) that call other skills.

```bash
#!/usr/bin/env bash
# deploy - Review, test, commit, and push

set -euo pipefail

echo "Running review..."
review || { echo "Review failed"; exit 1; }

echo "Running tests..."
./test.sh || { echo "Tests failed"; exit 1; }

echo "Shipping..."
ship "deploy: $(date +%Y-%m-%d)"

echo "Pushing..."
git push
```

**When to use:** Complex workflows, CI/CD-like local pipelines.

## Pattern 10: Context Windowing

For large inputs that exceed context limits.

```bash
#!/usr/bin/env bash
# Process large file in chunks

file="$1"
chunk_size=100  # lines

total_lines=$(wc -l < "$file")
chunks=$((total_lines / chunk_size + 1))

for ((i=0; i<chunks; i++)); do
  start=$((i * chunk_size + 1))
  sed -n "${start},$((start + chunk_size - 1))p" "$file" | \
    agen "Summarize this section (part $((i+1)) of $chunks)"
done | agen "Combine these section summaries into a coherent overview"
```

**When to use:** Large files, log analysis, book summarization.

## Anti-Patterns

### Don't: Build tools into agen

```bash
# Bad: Adding RAG inside agen
agen --rag --collection=emails "draft response"

# Good: Compose external tools
llm similar emails -c "$query" | xargs cat | agen "draft response"
```

### Don't: Use agen for everything

```bash
# Bad: Using agen to list files
agen "list all python files"

# Good: Use the right tool
find . -name "*.py"
```

### Don't: Ignore exit codes

```bash
# Bad: No error handling
agen "process" && echo "done"

# Good: Handle failures
if ! result=$(agen "process"); then
  echo "Agent failed" >&2
  exit 1
fi
```

### Don't: Stuff everything in the prompt

```bash
# Bad: Giant inline system prompt
agen "You are a code reviewer. You focus on bugs. You are concise. Review: $(cat file.py)"

# Good: Use system file
agen --system=REVIEWER.md "review this" < file.py
```
