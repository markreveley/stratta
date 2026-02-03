# Getting Started with Unix Agentics

This guide takes you from zero to productive with Unix-native AI agents.

## Prerequisites

- A Unix-like environment (macOS, Linux, WSL)
- Basic terminal comfort (`cd`, `ls`, `cat`, `|`)
- An LLM backend (Claude Code subscription, or API key)

## Installation

### Quick Setup

```bash
# Clone stratta and run setup
git clone https://github.com/markreveley/stratta.git
cd stratta
./setup.sh
source ~/.zshrc  # or ~/.bashrc
```

### Manual Setup

If you prefer to understand each step:

**1. Install agen (the core CLI)**

```bash
git clone https://github.com/markreveley/agen.git ~/tools/agen
echo 'export PATH="$HOME/tools/agen:$PATH"' >> ~/.zshrc
```

**2. Install llm (for embeddings and multi-provider support)**

```bash
pip install llm
llm keys set anthropic  # if using API
```

**3. Install agen-skills (optional workflow scripts)**

```bash
git clone https://github.com/markreveley/agen-skills.git ~/tools/agen-skills
echo 'export PATH="$HOME/tools/agen-skills:$PATH"' >> ~/.zshrc
```

**4. Install glow (optional markdown rendering)**

```bash
brew install glow  # macOS
# or: sudo apt install glow  # Debian/Ubuntu
```

## Your First Agent Call

```bash
# Simple query
agen "Explain the Unix philosophy in one sentence"

# With piped input
echo "The quick brown fox jumps over the lazy dog" | agen "Count the words"

# Render output as formatted markdown
agen "Explain pipes vs redirection" | glow
```

## Understanding the Stack

```
┌─────────────────────────────────────────┐
│           Your shell (zsh/bash)         │  ← You orchestrate
├─────────────────────────────────────────┤
│         agen (prompt composition)       │  ← Layers system + input + task
├─────────────────────────────────────────┤
│    Backend: claude-code | llm | api     │  ← LLM access
├─────────────────────────────────────────┤
│            LLM providers                │  ← Inference
└─────────────────────────────────────────┘
```

agen doesn't replace your shell — it's one tool in your pipeline.

## Backend Selection

agen auto-detects available backends in this order:

| Backend | Requires | Cost | Best for |
|---------|----------|------|----------|
| `claude-code` | Claude Code CLI | Max subscription | Daily use, no API costs |
| `llm` | llm CLI | API costs | Multi-provider flexibility |
| `api` | ANTHROPIC_API_KEY | API costs | Minimal dependencies |

Override with `--backend=` or `AGEN_BACKEND=`:

```bash
agen --backend=llm "hello"
# or
export AGEN_BACKEND=llm
```

## System Prompts

Create domain-specific agents with system prompts:

```bash
# Create a code reviewer
cat > REVIEWER.md << 'EOF'
You are a code reviewer. Be concise. Focus on bugs and security issues.
Skip style nitpicks unless they affect readability.
EOF

# Use it
git diff | agen --system=REVIEWER.md "Review these changes"
```

## The `shell` Helper

Add natural language → command translation to your shell:

```bash
# Add to ~/.zshrc
shell() {
  print -z "$(agen "Convert to a shell command. Output ONLY the raw command. No markdown, no code blocks, no explanation, no backticks. Just the command itself: $*")"
}
```

Usage:

```bash
shell find all python files modified in the last week
# Stages: find . -name "*.py" -mtime -7 (review, then Enter)
```

## Next Steps

1. **Read the patterns** — [PATTERNS.md](PATTERNS.md) covers RAG, drafting, and more
2. **Explore tools** — [TOOLS.md](TOOLS.md) lists the recommended stack
3. **Try tourlab** — A complete domain example for tour advancing
4. **Read the thesis** — [PHILOSOPHY.md](PHILOSOPHY.md) explains *why*

## Common Issues

### "agen: No prompt provided"

You need to provide a task:

```bash
agen "your question here"
# or
echo "input" | agen "what to do with it"
```

### "claude CLI not found"

Install Claude Code, or use a different backend:

```bash
export AGEN_BACKEND=api
export ANTHROPIC_API_KEY="your-key"
```

### "llm CLI not found"

```bash
pip install llm
```

### Output includes markdown formatting

The LLM returns markdown by default. Pipe to `glow` for rendering:

```bash
agen "explain something" | glow
```

Or ask for plain text:

```bash
agen "explain something in plain text, no markdown"
```
