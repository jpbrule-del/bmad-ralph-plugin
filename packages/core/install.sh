#!/bin/bash
# Ralph Installer v2.0
# Installs Ralph as a BMAD Method Phase 5 workflow
# Properly integrates with BMAD ecosystem

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "${BLUE}→ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    RALPH INSTALLER v2.0                              ║${NC}"
echo -e "${CYAN}║              BMAD Method Phase 5 - Autonomous Execution              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Determine source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"

# Check for required source file
if [ ! -f "$SOURCE_DIR/skills/ralph/SKILL.md" ]; then
  log_error "SKILL.md not found in $SOURCE_DIR/skills/ralph/"
  exit 1
fi

log_success "Found Ralph source at $SOURCE_DIR/skills/ralph/SKILL.md"

# ═══════════════════════════════════════════════════════════════════════════════
# BMAD INSTALLATION (Primary)
# ═══════════════════════════════════════════════════════════════════════════════

BMAD_COMMANDS="$HOME/.claude/commands/bmad"

echo ""
log_info "Installing Ralph as BMAD workflow..."

if [ -d "$BMAD_COMMANDS" ]; then
  log_success "Found BMAD commands directory at $BMAD_COMMANDS"

  # Create the BMAD workflow file
  cat > "$BMAD_COMMANDS/ralph.md" << 'BMAD_WORKFLOW_EOF'
---
description: 'Phase 5 autonomous execution - implement all stories from BMAD sprint planning'
---

# Ralph - BMAD Method Phase 5: Autonomous Execution

You are Ralph, the BMAD Method Phase 5 Autonomous Execution Agent.

## Purpose

After completing BMAD Phases 1-4 (product-brief, PRD, architecture, sprint-planning),
Ralph autonomously implements all stories from your sprint plan using Claude Code CLI.

## Prerequisites

Before running Ralph, ensure you have:
- Completed BMAD Phases 1-4 (or at minimum: PRD + sprint-status.yaml)
- `docs/sprint-status.yaml` with stories defined
- Claude Code CLI installed (`claude` command available)
- `jq` installed for JSON processing

## Invocation

```
/ralph
```

Ralph will:
1. Read your BMAD documentation (product-brief, PRD, architecture, sprint-plan)
2. Interview you to select stories and configure quality gates
3. Generate execution files (prd.json, prompt.md, loop script)
4. Execute a headless loop implementing stories one-by-one
5. Update sprint-status.yaml as stories complete

## Documentation

For full workflow details, see: ~/.claude/config/bmad/skills/ralph/SKILL.md

Or visit: https://github.com/bmad-method/ralph
BMAD_WORKFLOW_EOF

  log_success "Created BMAD workflow: $BMAD_COMMANDS/ralph.md"

else
  log_warn "BMAD commands directory not found at $BMAD_COMMANDS"
  log_info "Creating BMAD directory structure..."
  mkdir -p "$BMAD_COMMANDS"

  # Create workflow file
  cat > "$BMAD_COMMANDS/ralph.md" << 'BMAD_WORKFLOW_EOF'
---
description: 'Phase 5 autonomous execution - implement all stories from BMAD sprint planning'
---

# Ralph - BMAD Method Phase 5: Autonomous Execution

You are Ralph, the BMAD Method Phase 5 Autonomous Execution Agent.

## Purpose

After completing BMAD Phases 1-4 (product-brief, PRD, architecture, sprint-planning),
Ralph autonomously implements all stories from your sprint plan using Claude Code CLI.

## Prerequisites

Before running Ralph, ensure you have:
- Completed BMAD Phases 1-4 (or at minimum: PRD + sprint-status.yaml)
- `docs/sprint-status.yaml` with stories defined
- Claude Code CLI installed (`claude` command available)
- `jq` installed for JSON processing

## Invocation

```
/ralph
```

Ralph will:
1. Read your BMAD documentation (product-brief, PRD, architecture, sprint-plan)
2. Interview you to select stories and configure quality gates
3. Generate execution files (prd.json, prompt.md, loop script)
4. Execute a headless loop implementing stories one-by-one
5. Update sprint-status.yaml as stories complete

## Documentation

For full workflow details, see: ~/.claude/config/bmad/skills/ralph/SKILL.md

Or visit: https://github.com/bmad-method/ralph
BMAD_WORKFLOW_EOF

  log_success "Created BMAD workflow: $BMAD_COMMANDS/ralph.md"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SKILL FILE INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
log_info "Installing Ralph skill documentation..."

SKILL_DIR="$HOME/.claude/config/bmad/skills/ralph"
mkdir -p "$SKILL_DIR"

cp "$SOURCE_DIR/skills/ralph/SKILL.md" "$SKILL_DIR/SKILL.md"
log_success "Installed: $SKILL_DIR/SKILL.md"

# ═══════════════════════════════════════════════════════════════════════════════
# SKILL REGISTRATION (for Skill tool recognition)
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
log_info "Registering Ralph as Claude Code skill..."

SKILLS_DIR="$HOME/.claude/skills/bmad"
mkdir -p "$SKILLS_DIR"

cat > "$SKILLS_DIR/ralph.md" << 'SKILL_EOF'
---
name: ralph
description: "BMAD Phase 5 - Autonomous story implementation from sprint planning"
---

# Ralph Skill

Autonomously implement all stories from BMAD sprint planning.

## Usage

Run `/ralph` after completing BMAD Phases 1-4.

## Full Documentation

See `~/.claude/config/bmad/skills/ralph/SKILL.md` for complete workflow.
SKILL_EOF

log_success "Registered skill: $SKILLS_DIR/ralph.md"

# ═══════════════════════════════════════════════════════════════════════════════
# EXISTING /ralph CHECK
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
STANDALONE_RALPH="$HOME/.claude/commands/ralph.md"
if [ -f "$STANDALONE_RALPH" ]; then
  log_warn "Found existing standalone /ralph at $STANDALONE_RALPH"
  echo ""
  echo -e "${YELLOW}Note: The existing /ralph is a standalone feature implementation workflow.${NC}"
  echo -e "${YELLOW}BMAD Ralph is different - it reads your BMAD planning docs.${NC}"
  echo ""
  echo "Both can coexist:"
  echo "  • /ralph        → Standalone feature implementation"
  echo "  • /bmad/ralph   → BMAD Phase 5 autonomous execution"
  echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECK
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
log_info "Checking dependencies..."

DEPS_OK=true

if command -v jq >/dev/null 2>&1; then
  log_success "jq installed ($(jq --version))"
else
  log_error "jq not installed - REQUIRED for Ralph"
  echo "  Install with: brew install jq (macOS) or apt install jq (Linux)"
  DEPS_OK=false
fi

if command -v claude >/dev/null 2>&1; then
  log_success "Claude CLI installed"
else
  log_error "Claude CLI not installed - REQUIRED for Ralph"
  echo "  Install with: npm install -g @anthropic-ai/claude-code"
  DEPS_OK=false
fi

if command -v yq >/dev/null 2>&1; then
  log_success "yq installed (recommended for sprint-status.yaml updates)"
else
  log_warn "yq not installed (optional but recommended)"
  echo "  Install with: brew install yq (macOS)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
if [ "$DEPS_OK" = true ]; then
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                  RALPH INSTALLED SUCCESSFULLY                        ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
else
  echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}║            RALPH INSTALLED (missing dependencies)                    ║${NC}"
  echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo "Installation Summary:"
echo "  • BMAD Workflow:  $BMAD_COMMANDS/ralph.md"
echo "  • Skill Docs:     $SKILL_DIR/SKILL.md"
echo "  • Skill Register: $SKILLS_DIR/ralph.md"
echo ""
echo "Usage:"
echo "  1. Complete BMAD Phases 1-4 in your project:"
echo "     /product-brief → /prd → /architecture → /sprint-planning"
echo "  2. Run: /ralph (or /bmad/ralph)"
echo "  3. Follow the configuration interview"
echo "  4. Let Ralph implement your stories autonomously!"
echo ""
echo "Documentation: $SKILL_DIR/SKILL.md"
echo "Repository:    https://github.com/bmad-method/ralph"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SHARING INSTRUCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                     SHARING WITH OTHER USERS                          ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "To share Ralph with other BMAD users:"
echo ""
echo "  Option 1: Direct Installation"
echo "    git clone https://github.com/bmad-method/ralph"
echo "    cd ralph && ./install.sh"
echo ""
echo "  Option 2: Add to BMAD Distribution"
echo "    Copy skills/ralph/ to your BMAD installation's skills folder"
echo "    Copy the workflow file to ~/.claude/commands/bmad/"
echo ""
