#!/bin/bash
# Ralph Installer
# Installs Ralph as a BMAD Method Phase 5 workflow

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "${BLUE}→ $1${NC}"; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      RALPH INSTALLER                                  ║${NC}"
echo -e "${BLUE}║              BMAD Method Phase 5 - Autonomous Execution              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for Claude Code config directory
CLAUDE_CONFIG="$HOME/.claude/config"
BMAD_DIR="$CLAUDE_CONFIG/bmad"

if [ ! -d "$BMAD_DIR" ]; then
  log_error "BMAD not found at $BMAD_DIR"
  echo "Please install BMAD Method first: https://github.com/bmad-method/bmad"
  exit 1
fi

log_info "Found BMAD installation at $BMAD_DIR"

# Determine source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"

# Check for required files
if [ ! -f "$SOURCE_DIR/skills/ralph/SKILL.md" ]; then
  log_error "SKILL.md not found in $SOURCE_DIR/skills/ralph/"
  exit 1
fi

# Create skills directory if needed
SKILLS_DIR="$BMAD_DIR/skills/ralph"
mkdir -p "$SKILLS_DIR"

# Copy skill file
log_info "Installing Ralph skill..."
cp "$SOURCE_DIR/skills/ralph/SKILL.md" "$SKILLS_DIR/SKILL.md"
log_success "Installed SKILL.md"

# Create workflow file
WORKFLOW_DIR="$BMAD_DIR/modules/bmm/workflows"
mkdir -p "$WORKFLOW_DIR"

log_info "Creating BMAD workflow registration..."
cat > "$WORKFLOW_DIR/ralph.md" << 'WORKFLOW_EOF'
---
name: ralph
description: "Phase 5 autonomous loop execution - implements all stories from BMAD planning"
---

# Ralph - BMAD Autonomous Execution Workflow

Phase 5 of the BMAD Method. After completing product brief, PRD, architecture,
and sprint planning, run `/ralph` to autonomously implement all stories.

See `~/.claude/config/bmad/skills/ralph/SKILL.md` for full workflow.
WORKFLOW_EOF
log_success "Created workflow file"

# Check dependencies
echo ""
log_info "Checking dependencies..."

if command -v jq >/dev/null 2>&1; then
  log_success "jq installed ($(jq --version))"
else
  log_error "jq not installed - required for Ralph"
  echo "  Install with: brew install jq (macOS) or apt install jq (Linux)"
fi

if command -v claude >/dev/null 2>&1; then
  log_success "Claude CLI installed"
else
  log_error "Claude CLI not installed - required for Ralph"
  echo "  Install with: npm install -g @anthropic-ai/claude-code"
fi

if command -v yq >/dev/null 2>&1; then
  log_success "yq installed (optional, for better YAML handling)"
else
  echo -e "${YELLOW}⚠ yq not installed (optional)${NC}"
  echo "  Install with: brew install yq (macOS) for better sprint-status.yaml updates"
fi

# Done
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    RALPH INSTALLED SUCCESSFULLY                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Usage:"
echo "  1. Complete BMAD Phases 1-4 (product-brief, PRD, architecture, sprint-planning)"
echo "  2. Run: /ralph"
echo "  3. Follow the configuration interview"
echo "  4. Let Ralph implement your stories autonomously!"
echo ""
echo "Documentation: $SKILLS_DIR/SKILL.md"
