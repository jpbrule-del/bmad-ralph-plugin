#!/usr/bin/env bash
# Ralph CLI - Complete Installation Script
# Installs the CLI globally and sets up Claude Code skills
#
# Usage: ./install.sh
#
# What this script does:
# 1. Checks prerequisites (Node.js, npm, git)
# 2. Installs system dependencies (jq, yq) if possible
# 3. Links the CLI globally via npm
# 4. Installs Claude Code skills to ~/.claude/commands/ralph/
# 5. Verifies the installation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#------------------------------------------------------------------------------
# Output helpers
#------------------------------------------------------------------------------
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

#------------------------------------------------------------------------------
# Check prerequisites
#------------------------------------------------------------------------------
check_prerequisites() {
  info "Checking prerequisites..."

  local missing=false

  # Node.js
  if command -v node &>/dev/null; then
    local node_version
    node_version=$(node --version | sed 's/v//')
    local major_version
    major_version=$(echo "$node_version" | cut -d. -f1)
    if [[ "$major_version" -ge 18 ]]; then
      success "Node.js $node_version"
    else
      warn "Node.js $node_version (v18+ recommended)"
    fi
  else
    error "Node.js is not installed"
    echo "  Install: https://nodejs.org/ or 'brew install node'"
    missing=true
  fi

  # npm
  if command -v npm &>/dev/null; then
    success "npm $(npm --version)"
  else
    error "npm is not installed"
    missing=true
  fi

  # git
  if command -v git &>/dev/null; then
    success "git $(git --version | awk '{print $3}')"
  else
    error "git is not installed"
    echo "  Install: 'brew install git' or 'sudo apt-get install git'"
    missing=true
  fi

  if [[ "$missing" == true ]]; then
    echo ""
    error "Please install missing prerequisites and try again"
    exit 1
  fi

  success "All prerequisites met"
}

#------------------------------------------------------------------------------
# Install system dependencies
#------------------------------------------------------------------------------
install_system_deps() {
  info "Checking system dependencies..."

  local needs_jq=false
  local needs_yq=false

  # Check jq
  if command -v jq &>/dev/null; then
    success "jq $(jq --version 2>&1 | head -1)"
  else
    warn "jq not found"
    needs_jq=true
  fi

  # Check yq
  if command -v yq &>/dev/null; then
    local yq_version
    yq_version=$(yq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major
    major=$(echo "$yq_version" | cut -d. -f1)
    if [[ -n "$major" ]] && [[ "$major" -ge 4 ]]; then
      success "yq v$yq_version"
    else
      warn "yq v$yq_version (v4.x+ recommended)"
    fi
  else
    warn "yq not found"
    needs_yq=true
  fi

  # Try to install missing deps on macOS
  if [[ "$needs_jq" == true ]] || [[ "$needs_yq" == true ]]; then
    if command -v brew &>/dev/null; then
      info "Installing missing dependencies via Homebrew..."
      if [[ "$needs_jq" == true ]]; then
        brew install jq 2>/dev/null && success "Installed jq" || warn "Could not install jq"
      fi
      if [[ "$needs_yq" == true ]]; then
        brew install yq 2>/dev/null && success "Installed yq" || warn "Could not install yq"
      fi
    else
      echo ""
      warn "Please install missing dependencies manually:"
      [[ "$needs_jq" == true ]] && echo "  jq: brew install jq (macOS) or sudo apt-get install jq (Linux)"
      [[ "$needs_yq" == true ]] && echo "  yq: brew install yq (macOS) or see https://github.com/mikefarah/yq"
      echo ""
      echo "The CLI will work, but some features require jq and yq."
      echo "Press Enter to continue or Ctrl+C to abort..."
      read -r
    fi
  fi
}

#------------------------------------------------------------------------------
# Install CLI globally
#------------------------------------------------------------------------------
install_cli() {
  info "Installing Ralph CLI globally..."

  cd "$SCRIPT_DIR/packages/cli"

  # Install npm dependencies
  npm install --silent
  success "Installed npm dependencies"

  # Link globally
  npm link 2>/dev/null || {
    warn "npm link failed (may need sudo)"
    echo "  Try: sudo npm link"
    echo "  Or add to PATH: export PATH=\"\$PATH:\$(npm config get prefix)/bin\""
  }

  cd "$SCRIPT_DIR"

  # Verify CLI is accessible
  if command -v ralph &>/dev/null; then
    success "Ralph CLI linked globally: $(which ralph)"
  else
    warn "CLI not in PATH yet. Add npm bin to your PATH:"
    echo "  export PATH=\"\$PATH:\$(npm config get prefix)/bin\""
    echo "  Then restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
  fi
}

#------------------------------------------------------------------------------
# Install Claude Code skills
#------------------------------------------------------------------------------
install_skills() {
  info "Installing Claude Code skills..."

  local skills_src="$SCRIPT_DIR/packages/cli/skills/ralph"
  local skills_dest="$HOME/.claude/commands/ralph"

  # Check if source exists
  if [[ ! -d "$skills_src" ]]; then
    error "Skills source not found: $skills_src"
    echo "  Make sure you're running from the ralph repository root"
    exit 1
  fi

  # Create destination directory
  mkdir -p "$skills_dest"

  # Copy skill files
  cp "$skills_src"/*.md "$skills_dest/"

  # Count installed files
  local count
  count=$(ls -1 "$skills_dest"/*.md 2>/dev/null | wc -l | tr -d ' ')
  success "Installed $count skill files to $skills_dest"

  # List installed skills
  echo ""
  echo "  Available Claude Code commands:"
  for skill in "$skills_dest"/*.md; do
    local name
    name=$(basename "$skill" .md)
    echo "    /ralph:$name"
  done
}

#------------------------------------------------------------------------------
# Verify installation
#------------------------------------------------------------------------------
verify_installation() {
  echo ""
  info "Verifying installation..."

  local all_ok=true

  # Check CLI
  if command -v ralph &>/dev/null; then
    local version
    version=$(ralph --version 2>&1)
    success "CLI: $version"
  else
    warn "CLI not in PATH (may need to restart terminal)"
    all_ok=false
  fi

  # Check skills
  local skills_dir="$HOME/.claude/commands/ralph"
  if [[ -d "$skills_dir" ]]; then
    local count
    count=$(ls -1 "$skills_dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -ge 13 ]]; then
      success "Skills: $count files in $skills_dir"
    else
      warn "Skills: Only $count files found (expected 13)"
      all_ok=false
    fi
  else
    warn "Skills directory not found: $skills_dir"
    all_ok=false
  fi

  echo ""
  if [[ "$all_ok" == true ]]; then
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}   Installation Complete!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. CLI usage:     ralph --help"
    echo "  2. In Claude Code: Type /ralph: to see available commands"
    echo ""
    echo "Quick start in a BMAD project:"
    echo "  ralph init"
    echo "  ralph create my-loop"
    echo "  ralph run my-loop"
    echo ""
  else
    echo -e "${YELLOW}==========================================${NC}"
    echo -e "${YELLOW}   Installation completed with warnings${NC}"
    echo -e "${YELLOW}==========================================${NC}"
    echo ""
    echo "Some components may need manual setup. See warnings above."
    echo ""
  fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Ralph CLI Installation${NC}"
  echo -e "${BLUE}   Autonomous AI Agent Loop${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  check_prerequisites
  echo ""
  install_system_deps
  echo ""
  install_cli
  echo ""
  install_skills
  verify_installation
}

main "$@"
