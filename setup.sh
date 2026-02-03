#!/usr/bin/env bash
#
# setup.sh - Install the Unix Agentics stack
#
# This script installs agen, agen-skills, llm, and configures your shell.
#
# Usage:
#   ./setup.sh
#
# Requirements:
#   - macOS or Linux
#   - bash or zsh
#   - git
#   - pip (for llm)
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[stratta]${NC} $*"; }
warn() { echo -e "${YELLOW}[stratta]${NC} $*"; }
error() { echo -e "${RED}[stratta]${NC} $*" >&2; }

# Detect shell config file
detect_shell_config() {
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    echo "$HOME/.zshrc"
  elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
    if [[ -f "$HOME/.bashrc" ]]; then
      echo "$HOME/.bashrc"
    else
      echo "$HOME/.bash_profile"
    fi
  else
    echo "$HOME/.profile"
  fi
}

SHELL_CONFIG=$(detect_shell_config)
TOOLS_DIR="$HOME/.local/share/stratta"

log "Unix Agentics Stack Setup"
log "========================="
echo ""

# Create tools directory
log "Creating tools directory: $TOOLS_DIR"
mkdir -p "$TOOLS_DIR"

# Install agen
if [[ -d "$TOOLS_DIR/agen" ]]; then
  log "agen already installed, updating..."
  cd "$TOOLS_DIR/agen" && git pull --quiet
else
  log "Installing agen..."
  git clone --quiet https://github.com/markreveley/agen.git "$TOOLS_DIR/agen"
fi

# Install agen-skills
if [[ -d "$TOOLS_DIR/agen-skills" ]]; then
  log "agen-skills already installed, updating..."
  cd "$TOOLS_DIR/agen-skills" && git pull --quiet
else
  log "Installing agen-skills..."
  git clone --quiet https://github.com/markreveley/agen-skills.git "$TOOLS_DIR/agen-skills"
fi

# Install llm via pip
if command -v llm &>/dev/null; then
  log "llm already installed"
else
  log "Installing llm..."
  if command -v pip3 &>/dev/null; then
    pip3 install --quiet llm
  elif command -v pip &>/dev/null; then
    pip install --quiet llm
  else
    warn "pip not found — install llm manually: pip install llm"
  fi
fi

# Install glow if on macOS with Homebrew
if command -v glow &>/dev/null; then
  log "glow already installed"
elif command -v brew &>/dev/null; then
  log "Installing glow via Homebrew..."
  brew install --quiet glow
else
  warn "Install glow manually for markdown rendering: brew install glow"
fi

# Configure shell
log "Configuring shell ($SHELL_CONFIG)..."

# Check if already configured
if grep -q "stratta" "$SHELL_CONFIG" 2>/dev/null; then
  log "Shell already configured"
else
  cat >> "$SHELL_CONFIG" << 'EOF'

# Unix Agentics (stratta)
export PATH="$HOME/.local/share/stratta/agen:$HOME/.local/share/stratta/agen-skills:$PATH"

# shell - natural language to shell command (stages in prompt, doesn't execute)
shell() {
  print -z "$(agen "Convert to a shell command. Output ONLY the raw command. No markdown, no code blocks, no explanation, no backticks. Just the command itself: $*")"
}
EOF
  log "Added stratta configuration to $SHELL_CONFIG"
fi

echo ""
log "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Reload your shell:  source $SHELL_CONFIG"
echo "  2. Test agen:          agen --version"
echo "  3. Test a query:       agen \"What is Unix?\""
echo ""
echo "If using Claude Code (Max subscription):"
echo "  - agen will auto-detect the claude CLI"
echo ""
echo "If using API directly:"
echo "  - export ANTHROPIC_API_KEY=\"your-key\""
echo "  - Or: llm keys set anthropic"
echo ""
echo "Documentation:"
echo "  - Getting started:  cat GETTING_STARTED.md | glow"
echo "  - Tools:            cat TOOLS.md | glow"
echo "  - Patterns:         cat PATTERNS.md | glow"
echo "  - Philosophy:       cat PHILOSOPHY.md | glow"
