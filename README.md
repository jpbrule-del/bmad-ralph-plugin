# Ralph

![Ralph](ralph.webp)

> **Autonomous AI agent loop for Claude Code** - Implements your stories while you sleep.

Ralph runs Claude Code CLI repeatedly until all PRD items are complete. Each iteration is a fresh Claude session with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## Quick Start

```bash
# Clone and install (one command)
git clone https://github.com/snarktank/ralph.git && cd ralph && ./install.sh

# Then in your BMAD project:
ralph init
ralph create my-sprint
ralph run my-sprint
```

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
   - [Automated Installation](#automated-installation)
   - [Manual Installation](#manual-installation)
3. [Claude Code Integration](#claude-code-integration)
4. [Usage Guide](#usage-guide)
5. [BMAD Method Integration](#bmad-method-integration)
6. [CLI Reference](#cli-reference)
7. [Configuration](#configuration)
8. [Troubleshooting](#troubleshooting)
9. [Development](#development)

---

## Prerequisites

Before installing Ralph, ensure you have:

| Requirement | Version | How to Check | Install |
|-------------|---------|--------------|---------|
| **Node.js** | 18+ | `node --version` | [nodejs.org](https://nodejs.org/) or `brew install node` |
| **npm** | 8+ | `npm --version` | Included with Node.js |
| **git** | 2.x+ | `git --version` | `brew install git` or `sudo apt-get install git` |
| **jq** | 1.6+ | `jq --version` | `brew install jq` or `sudo apt-get install jq` |
| **yq** | 4.x+ | `yq --version` | `brew install yq` or [mikefarah/yq](https://github.com/mikefarah/yq) |
| **Claude Code CLI** | latest | `claude --version` | `npm install -g @anthropic-ai/claude-code` |

**Important:** Claude Code CLI must be authenticated before using Ralph:
```bash
claude
# Follow the authentication prompts
```

---

## Installation

### Automated Installation

The install script handles everything:

```bash
# 1. Clone the repository
git clone https://github.com/snarktank/ralph.git
cd ralph

# 2. Run the installer
./install.sh
```

The installer will:
- Check all prerequisites
- Install missing system dependencies (jq, yq) on macOS
- Link the CLI globally via npm
- Install Claude Code skills to `~/.claude/commands/ralph/`
- Verify the installation

### Manual Installation

If you prefer manual control or need to debug issues:

#### Step 1: Clone Repository

```bash
git clone https://github.com/snarktank/ralph.git
cd ralph
```

#### Step 2: Install System Dependencies

**macOS (Homebrew):**
```bash
brew install jq yq
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq
# For yq v4, download from: https://github.com/mikefarah/yq/releases
```

**Verify:**
```bash
jq --version   # Should show jq-1.6 or higher
yq --version   # Should show v4.x
```

#### Step 3: Install Node Dependencies

```bash
cd packages/cli
npm install
```

#### Step 4: Link CLI Globally

```bash
cd packages/cli
npm link
```

If `npm link` fails, try:
```bash
sudo npm link
# Or add npm bin to PATH:
export PATH="$PATH:$(npm config get prefix)/bin"
```

**Verify CLI:**
```bash
ralph --version
# Should show: ralph version 1.0.0

which ralph
# Should show a path like /usr/local/bin/ralph or ~/.npm/bin/ralph
```

#### Step 5: Install Claude Code Skills

```bash
# Create skills directory
mkdir -p ~/.claude/commands/ralph

# Copy skill files from repo
cp packages/cli/skills/ralph/*.md ~/.claude/commands/ralph/
```

**Verify skills:**
```bash
ls ~/.claude/commands/ralph/
# Should show 13 .md files: init.md, create.md, run.md, etc.
```

#### Step 6: Verify Complete Installation

```bash
# Test CLI
ralph help

# Test in Claude Code
claude
# Type: /ralph:
# Should see autocomplete with all ralph commands
```

---

## Claude Code Integration

Ralph integrates with Claude Code through **skill files** - markdown files that define slash commands.

### How It Works

Claude Code reads `.md` files from `~/.claude/commands/` to create slash commands:

```
~/.claude/commands/
└── ralph/
    ├── init.md        → /ralph:init
    ├── create.md      → /ralph:create
    ├── run.md         → /ralph:run
    ├── status.md      → /ralph:status
    ├── list.md        → /ralph:list
    ├── show.md        → /ralph:show
    ├── edit.md        → /ralph:edit
    ├── clone.md       → /ralph:clone
    ├── delete.md      → /ralph:delete
    ├── archive.md     → /ralph:archive
    ├── unarchive.md   → /ralph:unarchive
    ├── config.md      → /ralph:config
    └── feedback-report.md → /ralph:feedback-report
```

### Available Slash Commands

| Command | Purpose |
|---------|---------|
| `/ralph:init` | Initialize Ralph in a BMAD project |
| `/ralph:create` | Create a new autonomous loop |
| `/ralph:run` | Execute the loop (runs Claude repeatedly) |
| `/ralph:status` | Monitor loop progress in real-time |
| `/ralph:list` | List all active and archived loops |
| `/ralph:show` | Display detailed loop information |
| `/ralph:edit` | Edit loop configuration |
| `/ralph:clone` | Copy a loop configuration |
| `/ralph:delete` | Remove a loop |
| `/ralph:archive` | Archive a completed loop |
| `/ralph:unarchive` | Restore an archived loop |
| `/ralph:config` | Manage Ralph configuration |
| `/ralph:feedback-report` | View aggregate feedback analytics |

### Re-installing Skills

If skills are missing or outdated:

```bash
# From the ralph repository
cp packages/cli/skills/ralph/*.md ~/.claude/commands/ralph/

# Or re-run the full installer
./install.sh
```

---

## Usage Guide

### 1. Initialize Ralph

In your BMAD project (must have `docs/sprint-status.yaml` or `bmad/config.yaml`):

```bash
ralph init
```

This creates:
- `ralph/config.yaml` - Global configuration
- `ralph/loops/` - Loop storage directory
- `ralph/archive/` - Archived loops directory

### 2. Create a Loop

```bash
ralph create sprint-1
```

This:
- Reads `docs/sprint-status.yaml` for pending stories
- Prompts for configuration (max iterations, quality gates)
- Generates loop files in `ralph/loops/sprint-1/`
- Creates git branch `ralph/sprint-1`

**Options:**
```bash
ralph create sprint-1 --epic EPIC-002    # Filter to specific epic
ralph create sprint-1 --yes              # Use defaults, skip prompts
ralph create sprint-1 --no-branch        # Don't create git branch
```

### 3. Run the Loop

```bash
ralph run sprint-1
```

Ralph will:
1. Pick the highest priority story where `passes: false`
2. Invoke Claude Code CLI to implement it
3. Run quality gates (typecheck, test, lint, build)
4. If gates pass: commit and mark story complete
5. Repeat until all stories pass or exit condition met

**Options:**
```bash
ralph run sprint-1 --dry-run    # Simulate without running Claude
ralph run sprint-1 --restart    # Start from beginning
```

### 4. Monitor Progress

In another terminal:

```bash
ralph status sprint-1
```

Shows:
- Overall progress (completed/total)
- Current story being worked on
- Iteration count
- Quality gate status
- Recent activity log

### 5. Archive When Done

```bash
ralph archive sprint-1
```

Collects feedback and moves the loop to `ralph/archive/`.

---

## BMAD Method Integration

Ralph is **Phase 5** of the BMAD Method workflow:

| Phase | Activity | Output |
|-------|----------|--------|
| 1 | Product Brief | `docs/product-brief-*.md` |
| 2 | PRD | `docs/prd-*.md` |
| 3 | Architecture | `docs/architecture-*.md` |
| 4 | Sprint Planning | `docs/sprint-status.yaml` |
| **5** | **Autonomous Execution (Ralph)** | Implemented code, commits |

### Required BMAD Documents

Ralph reads these files to understand your project:

- **`docs/sprint-status.yaml`** (required) - Stories and acceptance criteria
- **`docs/prd-*.md`** (recommended) - Requirements and context
- **`docs/architecture-*.md`** (recommended) - Patterns and tech stack
- **`bmad/config.yaml`** (optional) - BMAD configuration

### Installing Ralph Agent in BMAD Projects

```bash
ralph init --install-agent
```

This installs:
- `bmm/agents/ralph.md` - Agent definition for BMAD
- Updates `docs/bmm-workflow-status.yaml` - Workflow registration

---

## CLI Reference

### Project Initialization

```bash
ralph init [--force] [--install-agent]
```

| Flag | Description |
|------|-------------|
| `--force` | Reinitialize even if already initialized |
| `--install-agent` | Install BMAD agent integration files |

### Configuration

```bash
ralph config show                 # Display current config
ralph config quality-gates        # Configure quality gates interactively
```

### Loop Management

```bash
ralph create <name> [options]     # Create new loop
ralph list [--active] [--archived] [--json]
ralph show <name> [--json]
ralph edit <name>                 # Open in $EDITOR
ralph clone <source> <dest>
ralph delete <name> [--force]
```

### Loop Execution

```bash
ralph run <name> [--dry-run] [--restart]
ralph status <name> [--once] [--refresh <seconds>]
```

### Archival

```bash
ralph archive <name> [--skip-feedback]
ralph unarchive <name> [--reset-stats] [--no-branch]
ralph feedback-report [--json]
```

---

## Configuration

### Global Configuration

Located at `ralph/config.yaml`:

```yaml
version: "1.0"
project_name: "my-project"

bmad:
  sprint_status_path: "docs/sprint-status.yaml"
  config_path: "bmad/config.yaml"

defaults:
  max_iterations: 50
  stuck_threshold: 3
  quality_gates:
    typecheck: null          # e.g., "npm run typecheck"
    test: null               # e.g., "npm test"
    lint: true               # uses npm run lint
    build: true              # uses npm run build
```

### Quality Gates

Configure which checks run after each story:

```bash
ralph config quality-gates
```

Or edit `ralph/config.yaml` directly:

```yaml
defaults:
  quality_gates:
    typecheck: "npm run typecheck"
    test: "npm test"
    lint: "npm run lint"
    build: "npm run build"
```

### Loop Configuration

Each loop has its own config in `ralph/loops/<name>/prd.json`:

```json
{
  "config": {
    "maxIterations": 50,
    "stuckThreshold": 3,
    "qualityGates": {
      "lint": "npm run lint",
      "build": "npm run build"
    }
  }
}
```

---

## Troubleshooting

### "ralph: command not found"

```bash
# Option 1: Re-link
cd /path/to/ralph/packages/cli
npm link

# Option 2: Add npm bin to PATH
export PATH="$PATH:$(npm config get prefix)/bin"
# Add this to ~/.bashrc or ~/.zshrc for persistence

# Option 3: Use npx (slower but works)
cd /path/to/ralph/packages/cli
npx ralph --version
```

### Skills not showing in Claude Code

```bash
# 1. Verify files exist
ls ~/.claude/commands/ralph/
# Should show 13 .md files

# 2. If missing, copy them
cp /path/to/ralph/packages/cli/skills/ralph/*.md ~/.claude/commands/ralph/

# 3. Restart Claude Code
# Skills are loaded on startup
```

### "Not a BMAD project" error

Ralph requires a BMAD project. Minimum requirement:

```bash
# Either of these must exist:
docs/sprint-status.yaml
# OR
bmad/config.yaml
```

### Dependencies missing

```bash
# Check all dependencies
ralph help
# Will show which dependencies are missing with install commands

# Or check manually
jq --version
yq --version
git --version
claude --version
```

### npm link permission error

```bash
# Option 1: Use sudo
sudo npm link

# Option 2: Fix npm permissions (recommended)
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH="$PATH:$HOME/.npm-global/bin"
# Add the export to ~/.bashrc or ~/.zshrc

# Then re-run
cd packages/cli
npm link
```

### Loop stuck on a story

```bash
# Check progress log
cat ralph/loops/<name>/progress.txt | tail -50

# Check quality gate output
ralph status <name> --once

# Manual options:
# 1. Increase stuck threshold
ralph edit <name>
# Change config.stuckThreshold

# 2. Skip the story (mark as complete)
ralph edit <name>
# Set the story's "passes": true

# 3. Restart the loop
ralph run <name> --restart
```

---

## Development

### Repository Structure

```
ralph/
├── packages/
│   ├── cli/                    # Main npm package (@ralph/cli)
│   │   ├── bin/ralph           # CLI entry point (bash)
│   │   ├── lib/                # Bash libraries
│   │   │   ├── commands/       # Command implementations
│   │   │   ├── core/           # Utilities (output, git, etc.)
│   │   │   └── generator/      # Template generators
│   │   ├── skills/ralph/       # Claude Code skill files
│   │   └── templates/          # Loop file templates
│   ├── core/                   # Core bash utilities
│   └── skills/                 # Extended skill definitions
├── apps/
│   └── flowchart/              # Interactive visualization (React)
├── docs/                       # Project documentation
├── install.sh                  # One-command installer
└── README.md                   # This file
```

### Running from Source

```bash
# Clone
git clone https://github.com/snarktank/ralph.git
cd ralph

# Install dependencies
cd packages/cli
npm install

# Run directly (without global install)
./bin/ralph --version

# Or use npm link for global access
npm link
```

### Testing Changes

```bash
# After making changes to the CLI
cd packages/cli

# Test directly
./bin/ralph help

# Test in a BMAD project
cd /path/to/bmad-project
/path/to/ralph/packages/cli/bin/ralph init
```

---

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

To run locally:

```bash
cd apps/flowchart
npm install
npm run dev
```

---

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://claude.ai/claude-code)
- [BMAD Method](https://bmad.ai)

---

## License

MIT
