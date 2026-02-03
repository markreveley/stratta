# Unix Agentics Tool Stack

The recommended tools for practicing Unix Agentics. Each does one thing well.

## Core Stack

### agen — Prompt Composition

The opinionated layer. Composes system prompts, stdin, and tasks into structured prompts.

```bash
# Install
git clone https://github.com/markreveley/agen.git
export PATH="$PATH:/path/to/agen"

# Use
cat file.py | agen --system=REVIEWER.md "review this code"
```

**Why agen:** Enforces Vision B patterns. Prompt layering, no built-in tools, Unix filter design.

### llm — LLM Access & Embeddings

Simon Willison's Swiss Army knife for LLM access. agen can use it as a backend.

```bash
# Install
pip install llm

# Use for inference
echo "hello" | llm "translate to French"

# Use for embeddings (RAG)
llm embed-multi emails --files *.md -m 3-small
llm similar emails -c "load-in time" -n 3
```

**Why llm:** Multi-provider support, embeddings, schemas, plugins. The best plumbing.

**Relationship to agen:** agen can route through llm (`--backend=llm`), but they serve different purposes. llm is agnostic plumbing. agen is opinionated workflow.

### glow — Markdown Rendering

Render markdown in the terminal.

```bash
# Install
brew install glow  # macOS
sudo apt install glow  # Debian/Ubuntu

# Use
agen "explain pipes" | glow
```

**Why glow:** LLMs output markdown. glow makes it readable.

## Skills & Workflows

### agen-skills — Workflow Scripts

Pre-built skills that orchestrate agen for common tasks.

```bash
# Install
git clone https://github.com/markreveley/agen-skills.git
export PATH="$PATH:/path/to/agen-skills"

# Use
ship                    # Commit with README check
ship "feat: add X"      # Custom commit message
review                  # Review staged changes
review file.py          # Review specific file
```

**Why agen-skills:** Demonstrates the pattern — skills are shell scripts that orchestrate agen, not prompts inside agen.

## Recommended Additions

### jq — JSON Processing

Essential for working with APIs and structured data.

```bash
# Install
brew install jq

# Use
curl -s api.example.com/data | jq '.results[]'
```

### fzf — Fuzzy Finder

Interactive selection in pipelines.

```bash
# Install
brew install fzf

# Use
ls *.md | fzf | xargs agen "summarize"
```

### bat — Better cat

Syntax highlighting for file viewing.

```bash
# Install
brew install bat

# Use
bat code.py
```

### ripgrep (rg) — Better grep

Fast, sensible defaults.

```bash
# Install
brew install ripgrep

# Use
rg "pattern" --type py
```

## Embedding & RAG

For retrieval-augmented generation, use llm's embedding support:

```bash
# Index documents
llm embed-multi collection_name --files docs/*.md -m 3-small

# Find similar
llm similar collection_name -c "your query" -n 5

# Use in pipeline
similar=$(llm similar emails -c "$query" -n 3 | jq -r '.id')
cat $similar | agen "draft a response"
```

**Why llm for embeddings:** It's already installed (if using as backend), handles storage, supports multiple embedding models.

## Backend Comparison

| Tool | Purpose | When to use |
|------|---------|-------------|
| Claude Code CLI | LLM inference | Max subscription, no API costs |
| llm CLI | LLM inference + embeddings | Multi-provider, need embeddings |
| Direct API (curl) | LLM inference | Minimal deps, scripting |

agen abstracts this — you choose once, it routes appropriately.

## The Stack Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Your workflows                        │
│  (skills, scripts, one-liners)                          │
├─────────────────────────────────────────────────────────┤
│  agen          │  glow      │  jq       │  fzf          │
│  (prompts)     │  (render)  │  (json)   │  (select)     │
├─────────────────────────────────────────────────────────┤
│  llm (embeddings + inference) | claude | api            │
├─────────────────────────────────────────────────────────┤
│                    LLM providers                         │
│  (Anthropic, OpenAI, Ollama, etc.)                      │
└─────────────────────────────────────────────────────────┘
```

## Installation Summary

```bash
# Core
git clone https://github.com/markreveley/agen.git ~/tools/agen
pip install llm
brew install glow

# Skills
git clone https://github.com/markreveley/agen-skills.git ~/tools/agen-skills

# Recommended
brew install jq fzf bat ripgrep

# PATH
export PATH="$HOME/tools/agen:$HOME/tools/agen-skills:$PATH"
```

Or just run `./setup.sh` in this repo.
