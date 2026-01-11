# BMAD Ralph Plugin

> **Autonomous AI agent loop for Claude Code** - Implements your stories while you sleep.

Ralph runs Claude Code repeatedly until all sprint stories are complete. Each iteration is a fresh Claude session with clean context. Memory persists via git history, `progress.txt`, and sprint status tracking.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-blue.svg)](https://claude.com/claude-code)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)](https://github.com/snarktank/ralph)

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Quick Install (Marketplace)](#quick-install-marketplace)
  - [Manual Installation](#manual-installation)
- [Quick Start](#quick-start)
- [Commands Reference](#commands-reference)
- [Hooks System](#hooks-system)
- [MCP Integration](#mcp-integration)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [How It Works](#how-it-works)
- [BMAD Method Integration](#bmad-method-integration)
- [License](#license)

---

## Features

### Core Features
- **Autonomous Execution** - Runs Claude Code repeatedly until all stories are complete
- **BMAD Method Integration** - Works seamlessly with sprint-status.yaml from BMAD Phase 4
- **Quality Gates** - Automatic testing (lint, build, test) after each story
- **Git Workflow** - Atomic commits with conventional commit messages
- **Progress Tracking** - Real-time monitoring with detailed iteration logs
- **Stuck Detection** - Alerts when stories need manual intervention

### Advanced Features
- **Hooks System** - Automate actions on lifecycle events (pre-commit, post-story, loop-complete)
- **Skills & Agents** - Auto-invoked optimization suggestions and specialized execution agents
- **MCP Integration** - Research capabilities via Perplexity AI during execution
- **Auto-Updates** - Stay current with latest features via marketplace
- **Feedback Analytics** - Track loop effectiveness and identify improvement patterns

---

## Prerequisites

Before installing the BMAD Ralph Plugin, ensure you have:

| Requirement | Version | Purpose |
|-------------|---------|---------|
| **Claude Code** | 1.0+ | Plugin runtime |
| **git** | 2.0+ | Version control operations |
| **jq** | 1.6+ | JSON processing |
| **yq** | 4.0+ | YAML processing |
| **Node.js** | 18+ (optional) | For quality gates (npm test, build) |

**Verify prerequisites:**
```bash
git --version   # Should show git version 2.x or higher
jq --version    # Should show jq-1.6 or higher
yq --version    # Should show version 4.x
```

**Install missing dependencies:**

**macOS (Homebrew):**
```bash
brew install jq yq
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq
# For yq v4, download from: https://github.com/mikefarah/yq/releases
```

**Fedora:**
```bash
sudo dnf install jq
# For yq v4, download from: https://github.com/mikefarah/yq/releases
```

---

## Installation

### Quick Install (Marketplace)

**Recommended method for most users.**

1. Install from Claude Code marketplace:
```bash
# In Claude Code
/plugin install bmad-ralph
```

2. Verify installation:
```bash
# In Claude Code, type:
/bmad-ralph:
# Should show all available commands
```

### Manual Installation

**For development or custom installations.**

1. Clone the repository:
```bash
git clone https://github.com/snarktank/ralph.git
cd ralph
```

2. Install the plugin:
```bash
# Copy plugin files to Claude Code plugins directory
mkdir -p ~/.claude/plugins/bmad-ralph
cp -r .claude-plugin/* ~/.claude/plugins/bmad-ralph/
```

3. Restart Claude Code to load the plugin.

4. Verify installation:
```bash
# In Claude Code
/bmad-ralph:init --help
```

---

## Quick Start

### 1. Initialize Ralph in Your Project

```bash
# In Claude Code, in your BMAD project directory
/bmad-ralph:init
```

**What this creates:**
- `ralph/config.yaml` - Global Ralph configuration
- `ralph/loops/` - Directory for automation loops
- `ralph/archive/` - Archived completed loops

### 2. Create an Automation Loop

```bash
# Create a loop for your sprint
/bmad-ralph:create plugin-sprint
```

**Interactive prompts will ask:**
- Max iterations (default: 100)
- Stuck threshold (default: 3)
- Quality gates to enable (lint, build, test)
- Whether to filter by epic

### 3. Run the Loop

```bash
# Start autonomous execution
/bmad-ralph:run plugin-sprint
```

**Ralph will:**
1. Read `docs/sprint-status.yaml` for pending stories
2. Pick highest priority story with `status: "not-started"`
3. Implement the story following architecture patterns
4. Run quality gates (lint, build, test)
5. Commit on success with message: `feat: STORY-XXX - Story Title`
6. Update sprint-status.yaml: set story `status: "completed"`
7. Repeat until all stories are done

### 4. Monitor Progress

```bash
# In another Claude Code session
/bmad-ralph:status plugin-sprint
```

**Live dashboard shows:**
- Overall progress (36/40 stories completed)
- Current story being implemented
- Iteration count (66 iterations)
- Quality gate status (✅ lint, ✅ build)
- Recent activity log
- ETA calculation

### 5. Archive When Complete

```bash
# Collect feedback and archive
/bmad-ralph:archive plugin-sprint
```

**Feedback questionnaire asks:**
- Satisfaction rating (1-5)
- Manual interventions needed
- What worked well
- What should improve
- Would you run this loop again?

---

## Commands Reference

### Project Initialization

#### `/bmad-ralph:init`

Initialize Ralph in a BMAD project.

**Usage:**
```bash
/bmad-ralph:init
/bmad-ralph:init --force              # Reinitialize existing project
/bmad-ralph:init --install-agent      # Install BMAD agent integration
```

**What it does:**
- Creates `ralph/` directory structure
- Generates `ralph/config.yaml` with defaults
- Detects quality gates from package.json
- Optionally installs BMAD agent files

**Prerequisites:**
- Must be in a BMAD project (has `docs/sprint-status.yaml` or `bmad/config.yaml`)

---

### Loop Management

#### `/bmad-ralph:create <name>`

Create a new automation loop.

**Usage:**
```bash
/bmad-ralph:create plugin-sprint
/bmad-ralph:create plugin-sprint --epic EPIC-002    # Filter to specific epic
/bmad-ralph:create plugin-sprint --yes              # Use defaults, skip prompts
/bmad-ralph:create plugin-sprint --no-branch        # Don't create git branch
```

**What it does:**
- Reads `docs/sprint-status.yaml` for stories
- Prompts for configuration (or uses --yes for defaults)
- Generates loop files in `ralph/loops/<name>/`
- Creates git branch `ralph/<name>`

**Interactive prompts:**
- Max iterations (default: 100)
- Stuck threshold (default: 3)
- Quality gates to enable
- Epic filter (optional)

---

#### `/bmad-ralph:list`

List all automation loops.

**Usage:**
```bash
/bmad-ralph:list
/bmad-ralph:list --active              # Show only active loops
/bmad-ralph:list --archived            # Show only archived loops
/bmad-ralph:list --json                # Output as JSON
```

**Example output:**
```
Active Loops (2):
  plugin-sprint    36/40 stories  66 iterations  ralph/plugin-sprint
  hotfix-auth      5/5 stories    12 iterations  ralph/hotfix-auth

Archived Loops (1):
  2026-01-10-mvp   20/20 stories  45 iterations  Satisfaction: 5.0
```

---

#### `/bmad-ralph:show <name>`

Display detailed loop information.

**Usage:**
```bash
/bmad-ralph:show plugin-sprint
/bmad-ralph:show plugin-sprint --json
```

**What it shows:**
- Loop configuration (max iterations, stuck threshold, quality gates)
- Story progress breakdown (by attempt count)
- Execution statistics (iterations, stories completed, average)
- Quality gate results
- Feedback (for archived loops)

---

#### `/bmad-ralph:edit <name>`

Edit loop configuration.

**Usage:**
```bash
/bmad-ralph:edit plugin-sprint
```

**What it does:**
- Opens `config.json` in $EDITOR
- Validates JSON on save
- Creates backup for error recovery
- Prevents editing archived loops (read-only)

**Common edits:**
- Adjust `maxIterations`
- Change `stuckThreshold`
- Enable/disable quality gates
- Modify `customInstructions`

---

#### `/bmad-ralph:clone <source> <dest>`

Copy loop configuration.

**Usage:**
```bash
/bmad-ralph:clone plugin-sprint sprint-2
/bmad-ralph:clone 2026-01-10-mvp sprint-3    # Clone from archive
```

**What it does:**
- Copies all loop files
- Resets execution statistics
- Updates loop name in config.json
- Creates new git branch (interactive prompt)

**What gets preserved:**
- Configuration settings (quality gates, thresholds, custom instructions)
- Prompt template

**What gets reset:**
- `iterationsRun: 0`
- `storiesCompleted: 0`
- `storyAttempts: {}`
- `progress.txt` (new header)

---

#### `/bmad-ralph:delete <name>`

Remove a loop.

**Usage:**
```bash
/bmad-ralph:delete plugin-sprint
/bmad-ralph:delete plugin-sprint --force    # Skip confirmation
```

**What it does:**
- Prompts for confirmation (unless --force)
- Removes loop directory permanently
- Preserves git branch (provides manual deletion command)
- Cannot delete archived loops directly

**Safety features:**
- Confirmation prompt with warnings
- All-or-nothing operation
- Git branch preservation

---

### Loop Execution

#### `/bmad-ralph:run <name>`

Execute an automation loop.

**Usage:**
```bash
/bmad-ralph:run plugin-sprint
/bmad-ralph:run plugin-sprint --dry-run     # Simulate without running
/bmad-ralph:run plugin-sprint --restart     # Start from beginning
```

**What it does:**
1. Validates loop configuration
2. Switches to loop git branch
3. Creates lock file (prevents concurrent runs)
4. Delegates to `loop.sh` for story execution
5. Monitors for stuck detection
6. Cleans up lock file on exit

**Exit conditions:**
- All stories completed
- Max iterations reached
- Stuck threshold exceeded
- User interruption (Ctrl+C)

---

#### `/bmad-ralph:status <name>`

Monitor loop execution.

**Usage:**
```bash
/bmad-ralph:status plugin-sprint
/bmad-ralph:status plugin-sprint --once                # Single snapshot
/bmad-ralph:status plugin-sprint --refresh 5           # Refresh every 5 seconds
```

**Live dashboard shows:**
```
┌─ Ralph Loop Status: plugin-sprint ─────────────────────┐
│ Branch: ralph/plugin-sprint                            │
│ Progress: ████████████████░░░░ 36/40 stories (90.0%)  │
│ Iterations: 66/100                                     │
│ Quality Gates: ✅ lint | ✅ build                       │
│ Current Story: STORY-037 (Create Plugin README)       │
│ ETA: ~2 hours (based on avg 1.8 iterations/story)     │
└────────────────────────────────────────────────────────┘

Recent Activity (last 5):
  [10:14:12] STORY-036 completed (5 points) - commit 6a30117
  [10:08:19] STORY-035 completed (5 points) - commit a6729be
  [10:02:46] STORY-034 completed (5 points) - commit a5ddaea
  [09:55:59] STORY-033 completed (5 points) - commit c0e6f4c
  [09:48:15] STORY-032 completed (3 points) - commit a4a5c65

Keyboard controls:
  q - quit | r - refresh now | l - view full log
```

---

### Archival & Feedback

#### `/bmad-ralph:archive <name>`

Archive a completed loop.

**Usage:**
```bash
/bmad-ralph:archive plugin-sprint
/bmad-ralph:archive plugin-sprint --skip-feedback
```

**What it does:**
- Prompts for feedback questionnaire (5 questions)
- Moves loop to `ralph/archive/`
- Renames to `YYYY-MM-DD-<name>` format
- Saves `feedback.json` with responses

**Feedback questions:**
1. **Satisfaction:** Rate 1-5 overall satisfaction
2. **Manual Interventions:** How many times did you need to intervene?
3. **What Worked Well:** Free-text positive feedback
4. **What Should Improve:** Free-text improvement suggestions
5. **Run Again:** Would you run this loop again? (yes/no)

---

#### `/bmad-ralph:unarchive <name>`

Restore an archived loop.

**Usage:**
```bash
/bmad-ralph:unarchive plugin-sprint
/bmad-ralph:unarchive 2026-01-10-plugin-sprint         # Full archive name
/bmad-ralph:unarchive plugin-sprint --reset-stats      # Reset execution stats
/bmad-ralph:unarchive plugin-sprint --no-branch        # Skip git branch creation
```

**What it does:**
- Moves from `archive/` to `loops/`
- Preserves feedback.json for historical context
- Optionally resets execution statistics
- Optionally creates new git branch (interactive prompt)

**Use cases:**
- **Restore for continuation:** Unarchive without --reset-stats to continue where you left off
- **Reuse for rerun:** Unarchive with --reset-stats to run the same loop configuration fresh

---

#### `/bmad-ralph:feedback-report`

View aggregate feedback analytics.

**Usage:**
```bash
/bmad-ralph:feedback-report
/bmad-ralph:feedback-report --json
```

**Example output:**
```
┌─ Ralph Feedback Report ────────────────────────────────┐
│ Total Archived Loops: 5                                │
│ Date Range: 2026-01-05 to 2026-01-11                   │
└────────────────────────────────────────────────────────┘

Satisfaction Metrics:
  Average Score: 4.6/5.0 ⭐ (Excellent)
  Distribution:
    5 stars: ████████████████████░ 80% (4 loops)
    4 stars: █████░░░░░░░░░░░░░░░░ 20% (1 loop)
    3 stars: ░░░░░░░░░░░░░░░░░░░░░  0% (0 loops)
    2 stars: ░░░░░░░░░░░░░░░░░░░░░  0% (0 loops)
    1 star:  ░░░░░░░░░░░░░░░░░░░░░  0% (0 loops)

Success Rate:
  Would Run Again: 100% (5/5 loops) ✅ Strong confidence

Manual Intervention Rate:
  Average Interventions: 1.2 per loop ✅ Excellent autonomy
  0 interventions: 40% (2 loops)
  1-2 interventions: 40% (2 loops)
  3+ interventions: 20% (1 loop)

Common Themes (What Worked Well):
  - Quality gates prevented regressions (mentioned 5 times)
  - Git workflow kept history clean (mentioned 4 times)
  - Progress tracking very helpful (mentioned 3 times)

Common Themes (What Should Improve):
  - Sometimes got stuck on complex refactoring (mentioned 2 times)
  - Would like better handling of test failures (mentioned 1 time)
```

**Metrics thresholds:**
- **Satisfaction:** 4.0-5.0 = Excellent, 3.0-3.9 = Good, <3.0 = Needs Attention
- **Success Rate:** ≥75% = Strong confidence, 50-74% = Moderate, <50% = Review needed
- **Intervention Rate:** <10% = Excellent autonomy, 10-30% = Good, >30% = Review needed

---

### Configuration

#### `/bmad-ralph:config`

Manage Ralph configuration.

**Usage:**
```bash
/bmad-ralph:config show                    # Display current config
/bmad-ralph:config quality-gates           # Configure quality gates interactively
```

**What `show` displays:**
```yaml
version: "1.0"
project_name: "bmad-ralph-plugin"

bmad:
  sprint_status_path: "docs/sprint-status.yaml"
  config_path: "bmad/config.yaml"

defaults:
  max_iterations: 100
  stuck_threshold: 3
  quality_gates:
    lint: "npm run lint"      # ✅ Enabled
    build: "npm run build"    # ✅ Enabled
    test: null                # ❌ Disabled
```

**What `quality-gates` does:**
- Interactively prompts for each quality gate
- Validates JSON/YAML syntax before saving
- Uses atomic write pattern for safe updates
- Updates `ralph/config.yaml`

**Note:** Global config changes only affect newly created loops. Existing loops use their own `config.json`.

---

## Hooks System

Ralph's hooks system automates actions on lifecycle events. Hooks are defined in `.claude-plugin/hooks/hooks.json` and executed by the hook execution engine.

### Available Hook Types

| Hook Type | Phase | When It Runs | Can Block |
|-----------|-------|--------------|-----------|
| `plugin-load` | Initialization | Plugin startup | No (warn) |
| `pre-commit` | Pre-operation | Before git commit | Yes |
| `post-commit` | Post-operation | After git commit | No |
| `post-command` | Post-operation | After command completes | No |
| `post-story` | Post-operation | After story completion | No |
| `loop-start` | Lifecycle | Loop execution begins | No |
| `loop-pause` | Lifecycle | Loop execution paused | No |
| `loop-resume` | Lifecycle | Loop execution resumed | No |
| `loop-complete` | Lifecycle | All stories complete | No |
| `iteration-milestone` | Monitoring | Every 10 iterations | No |
| `quality-gate-failure` | Error handling | Quality gate fails | No (warn) |
| `stuck-detection` | Error handling | Story stuck detected | No (warn) |

### Core Hooks

#### Plugin Load Hooks

Run when plugin initializes (order matters):

1. **show-permissions.sh** - Display plugin permissions
2. **verify-dependencies.sh** - Check jq, yq, git availability
3. **validate-config.sh** - Validate ralph/config.yaml
4. **mcp-credential-validator.sh** - Validate MCP credentials
5. **auto-update-check.sh** - Check for plugin updates
6. **install-validate.sh** - Verify installation integrity

#### Pre-Commit Hook

**pre-commit-quality-gates.sh** - Runs quality gates before git commit

- Blocks commit if gates fail
- Provides clear error messages with last 20 lines of output
- Supports bypass via `RALPH_BYPASS_HOOKS` environment variable
- Logs all executions to `.ralph-cache/hooks.log`

**Usage:**
```bash
# Normal commit (gates run automatically)
git commit -m "feat: add new feature"

# Emergency bypass
RALPH_BYPASS_HOOKS=1 git commit -m "fix: hotfix bypass gates"
```

#### Post-Story Hook

**post-story-update.sh** - Runs after story completion

- Updates progress.txt with completion summary
- Sends optional webhook notification
- Supports auto-pickup of next story via `RALPH_AUTO_PICKUP_NEXT`
- Logs completion metrics

**Environment variables:**
```bash
# Enable webhook notifications
export RALPH_NOTIFICATION_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK"

# Enable auto-pickup next story
export RALPH_AUTO_PICKUP_NEXT=true
```

#### Lifecycle Hooks

**loop-start.sh** - Loop execution begins
- Logs start time to progress.txt
- Sends optional notification
- Supports custom scripts via `RALPH_CUSTOM_LOOP_START`

**loop-pause.sh** - Loop execution paused
- Calculates run duration
- Logs pause time
- Supports custom scripts via `RALPH_CUSTOM_LOOP_PAUSE`

**loop-resume.sh** - Loop execution resumed
- Calculates pause duration
- Clears pause time
- Supports custom scripts via `RALPH_CUSTOM_LOOP_RESUME`

**loop-complete.sh** - All stories complete
- Calculates total duration
- Shows completion summary
- Provides next steps guidance
- Supports custom scripts via `RALPH_CUSTOM_LOOP_COMPLETE`

**Loop context environment variables:**
```bash
RALPH_LOOP_NAME="plugin-sprint"
RALPH_LOOP_DIR="ralph/loops/plugin-sprint"
RALPH_BRANCH_NAME="ralph/plugin-sprint"
RALPH_STORIES_COMPLETED=36
RALPH_STORIES_TOTAL=40
RALPH_ITERATIONS_RUN=66
```

#### Stuck Detection Hook

**stuck-detection.sh** - Detects when loops need intervention

**Detection strategies:**
- **Story-level:** Story attempted ≥ threshold times
- **Loop-level:**
  - Remaining iterations < remaining stories
  - Zero completion rate after 20+ iterations
  - High average iterations per story (>5)

**Diagnostics provided:**
- Story attempts for each story
- Remaining iterations
- Completion rates
- Average iterations per story

**Resolution suggestions:**
- Review error logs in progress.txt
- Adjust quality gates if failing consistently
- Break down large stories
- Manual intervention may be required

### Custom Hooks

Add custom scripts to any hook:

```bash
# Example: Custom notification on loop complete
export RALPH_CUSTOM_LOOP_COMPLETE="/path/to/notify-team.sh"
```

Custom scripts receive loop context via environment variables.

### Hook Execution Engine

Manage hooks with the hook executor CLI:

```bash
# Execute a specific hook type
.claude-plugin/hooks/hook-executor.sh execute plugin-load

# List all registered hooks
.claude-plugin/hooks/hook-executor.sh list

# List available hook types
.claude-plugin/hooks/hook-executor.sh list-types

# Validate hooks.json configuration
.claude-plugin/hooks/hook-executor.sh validate

# View hook execution logs
.claude-plugin/hooks/hook-executor.sh logs
.claude-plugin/hooks/hook-executor.sh logs --tail 50
.claude-plugin/hooks/hook-executor.sh logs --type pre-commit
```

### Hook Logs

All hook executions are logged to `.ralph-cache/hooks.log`:

```
[2026-01-11T10:14:10Z] [plugin-load] [show-permissions] START
[2026-01-11T10:14:10Z] [plugin-load] [show-permissions] SUCCESS duration=0.23s
[2026-01-11T10:14:11Z] [pre-commit] [pre-commit-quality-gates] START
[2026-01-11T10:14:15Z] [pre-commit] [pre-commit-quality-gates] SUCCESS duration=4.12s
```

**Structured format:** `[timestamp] [hook_type] [hook_name] [status] [details]`

---

## MCP Integration

Ralph integrates with Model Context Protocol (MCP) to provide external research capabilities during loop execution.

### What is MCP?

MCP enables Ralph's agent to access external services like Perplexity AI for real-time research, current best practices, and troubleshooting.

### Available MCP Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `perplexity_search` | Quick web search | Finding recent documentation, checking current best practices |
| `perplexity_research` | Deep research | Understanding complex topics, architectural decisions |
| `perplexity_ask` | Conversational Q&A | Specific questions about technologies |
| `perplexity_reason` | Step-by-step reasoning | Complex problem-solving, debugging |

### Setup

1. **Get Perplexity API Key:**
   - Sign up at https://www.perplexity.ai/api
   - Copy your API key

2. **Configure credentials:**

**Option 1: Environment variable (recommended)**
```bash
export PERPLEXITY_API_KEY="your-api-key-here"

# Add to ~/.bashrc or ~/.zshrc for persistence
echo 'export PERPLEXITY_API_KEY="your-api-key-here"' >> ~/.bashrc
```

**Option 2: OS Keychain**
```bash
# Store in macOS keychain
.claude-plugin/mcp/mcp-credential-manager.sh set PERPLEXITY_API_KEY

# Retrieve from keychain
.claude-plugin/mcp/mcp-credential-manager.sh get PERPLEXITY_API_KEY
```

**Option 3: GPG encryption**
```bash
# Store encrypted credential
.claude-plugin/mcp/mcp-credential-manager.sh set PERPLEXITY_API_KEY --gpg
```

3. **Verify connection:**
```bash
.claude-plugin/mcp/mcp-test-connection.sh
```

**Expected output:**
```
✅ MCP Configuration valid
✅ Credentials available (PERPLEXITY_API_KEY)
✅ Connection test successful
✅ Rate limiting configured (10 req/min)
✅ Cache enabled (TTL: 300s)
```

### Usage During Loop Execution

Ralph's agent automatically uses MCP when needed:

**When MCP is used:**
- Researching unfamiliar technologies or frameworks
- Finding current best practices for implementation
- Troubleshooting complex errors
- Understanding new API documentation

**When MCP is NOT used:**
- Exploring existing codebase (uses Read/Grep tools)
- Following established project patterns (uses built-in knowledge)
- Simple implementation tasks

### Usage Analytics

View MCP usage statistics:

```bash
.claude-plugin/mcp/mcp-usage-stats.sh
```

**Example output:**
```
┌─ MCP Usage Statistics ─────────────────────────────────┐
│ Period: 2026-01-11 08:00 to 10:14 (2h 14m)            │
└────────────────────────────────────────────────────────┘

Total Requests: 15
  ├─ perplexity_search: 8 (53.3%)
  ├─ perplexity_research: 5 (33.3%)
  ├─ perplexity_ask: 2 (13.3%)
  └─ perplexity_reason: 0 (0.0%)

Cache Performance:
  ├─ Cache hits: 3 (20.0%)
  └─ Cache misses: 12 (80.0%)

Rate Limiting:
  ├─ Requests per minute: 10 (limit: 10)
  └─ Status: ✅ Within limits

Top Query Topics:
  1. "TypeScript generic constraints" (3 requests)
  2. "React Context performance" (2 requests)
  3. "Git branch naming conventions" (2 requests)
```

### Configuration

MCP configuration is in `.claude-plugin/.mcp.json`:

```json
{
  "servers": {
    "perplexity": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-perplexity"],
      "env": {
        "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}"
      },
      "capabilities": ["search", "research", "reasoning"],
      "retry_policy": {
        "max_attempts": 3,
        "backoff_multiplier": 2,
        "max_backoff_seconds": 30
      },
      "timeout_seconds": 30
    }
  },
  "rate_limiting": {
    "requests_per_minute": 10,
    "burst_size": 5
  },
  "cache": {
    "enabled": true,
    "ttl_seconds": 300
  }
}
```

### Security

**Best practices:**
- ✅ Store API keys in environment variables, never in code
- ✅ Use OS keychain for long-term storage
- ✅ Enable log sanitization (automatic)
- ✅ Rotate API keys regularly
- ✅ Use validation on startup

**What Ralph does automatically:**
- Credentials are never logged (sanitized by mcp-log-sanitizer.sh)
- API keys are redacted in error messages
- GPG encryption available for stored credentials
- Credential validation on plugin load

For detailed security documentation, see `.claude-plugin/MCP-SECURITY.md`.

---

## Configuration

### Global Configuration

**Location:** `ralph/config.yaml`

**Default configuration:**
```yaml
version: "1.0"
project_name: "my-project"

bmad:
  sprint_status_path: "docs/sprint-status.yaml"
  config_path: "bmad/config.yaml"

defaults:
  max_iterations: 100
  stuck_threshold: 3
  quality_gates:
    lint: "npm run lint"
    build: "npm run build"
    test: null
```

**Configuration fields:**

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `max_iterations` | number | Maximum iterations before stopping | 100 |
| `stuck_threshold` | number | Story attempts before stuck detection | 3 |
| `quality_gates.lint` | string\|null | Lint command or null to disable | `npm run lint` |
| `quality_gates.build` | string\|null | Build command or null to disable | `npm run build` |
| `quality_gates.test` | string\|null | Test command or null to disable | null |

**Editing global config:**
```bash
# Interactive quality gates configuration
/bmad-ralph:config quality-gates

# Or edit directly
code ralph/config.yaml
```

### Loop Configuration

**Location:** `ralph/loops/<name>/config.json`

Each loop has its own configuration file that overrides global defaults:

```json
{
  "project": "bmad-ralph-plugin",
  "loopName": "plugin-sprint",
  "branchName": "ralph/plugin-sprint",
  "sprintStatusPath": "docs/sprint-status.yaml",
  "config": {
    "maxIterations": 100,
    "stuckThreshold": 3,
    "qualityGates": {
      "lint": "npm run lint",
      "build": "npm run build",
      "test": null
    },
    "customInstructions": null
  }
}
```

**Editing loop config:**
```bash
# Open in $EDITOR
/bmad-ralph:edit plugin-sprint

# Or edit directly
code ralph/loops/plugin-sprint/config.json
```

**Custom instructions:**

Add project-specific guidance to the loop:

```json
{
  "config": {
    "customInstructions": "Follow the existing command pattern in .claude-plugin/commands/. Each command should have comprehensive documentation including examples, troubleshooting, and implementation notes."
  }
}
```

### Quality Gates

Quality gates run automatically after each story completion. Configure which gates to enable:

**Via interactive CLI:**
```bash
/bmad-ralph:config quality-gates
```

**Via YAML (global):**
```yaml
defaults:
  quality_gates:
    lint: "npm run lint"         # Enable with custom command
    build: "npm run build"        # Enable with custom command
    test: "npm test"              # Enable with custom command
    typecheck: null               # Disable by setting to null
```

**Via JSON (per-loop):**
```json
{
  "config": {
    "qualityGates": {
      "lint": "npm run lint",
      "build": "npm run build",
      "test": "npm test",
      "typecheck": null
    }
  }
}
```

**Quality gate execution:**
1. Gates run in order: typecheck → test → lint → build
2. If any gate fails, commit is blocked
3. Error details are shown in progress.txt
4. Loop attempts story again (up to stuck_threshold times)

---

## Troubleshooting

### Installation Issues

#### "Plugin not found" in Claude Code

**Cause:** Plugin not installed or Claude Code not restarted.

**Solutions:**
```bash
# Verify plugin directory exists
ls ~/.claude/plugins/bmad-ralph/

# If missing, reinstall from marketplace
/plugin install bmad-ralph

# Or manually copy files
mkdir -p ~/.claude/plugins/bmad-ralph
cp -r /path/to/ralph/.claude-plugin/* ~/.claude/plugins/bmad-ralph/

# Restart Claude Code
```

#### Dependencies missing (jq, yq, git)

**Cause:** System dependencies not installed.

**Check dependencies:**
```bash
jq --version    # Should show jq-1.6+
yq --version    # Should show version 4.x
git --version   # Should show git version 2.x+
```

**Install missing dependencies:**

**macOS:**
```bash
brew install jq yq
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq
# For yq, download from: https://github.com/mikefarah/yq/releases
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**Fedora:**
```bash
sudo dnf install jq
# For yq, download from: https://github.com/mikefarah/yq/releases
```

---

### Loop Execution Issues

#### "Not a BMAD project" error

**Cause:** Missing required BMAD files.

**Solution:**
```bash
# Ralph requires one of these files:
ls docs/sprint-status.yaml    # BMAD Phase 4 output (required)
ls bmad/config.yaml            # BMAD project config (optional)

# If missing, create sprint-status.yaml:
# See BMAD Method documentation for format
```

#### Loop stuck on a story

**Symptoms:**
- Story attempted multiple times (≥3)
- Same errors repeatedly
- Progress.txt shows no advancement

**Diagnosis:**
```bash
# Check recent progress
/bmad-ralph:show plugin-sprint

# Check stuck detection
tail -50 ralph/loops/plugin-sprint/progress.txt

# Check quality gate output
cat .ralph-cache/hooks.log | grep quality-gate
```

**Solutions:**

**Option 1: Increase stuck threshold**
```bash
/bmad-ralph:edit plugin-sprint
# Change "stuckThreshold": 3 to higher value
```

**Option 2: Adjust quality gates**
```bash
/bmad-ralph:edit plugin-sprint
# Disable failing gate temporarily:
# "lint": null
```

**Option 3: Manual implementation**
```bash
# Implement the story manually
git checkout ralph/plugin-sprint

# Make changes...

# Commit
git add .
git commit -m "feat: STORY-XXX - Manual implementation"

# Update sprint-status.yaml
# Set status: "completed" for the story

# Resume loop
/bmad-ralph:run plugin-sprint
```

#### Quality gates failing consistently

**Symptoms:**
- Pre-commit hook blocks commits
- Same test/lint failures repeatedly

**Diagnosis:**
```bash
# Run gates manually to see full output
npm run lint
npm run build
npm test

# Check last 20 lines of failed gate
tail -20 .ralph-cache/quality-gate-lint.log
```

**Solutions:**

**Option 1: Fix the underlying issue**
```bash
# Address the root cause (linting errors, test failures)
# Then resume loop
```

**Option 2: Temporarily disable failing gate**
```bash
/bmad-ralph:edit plugin-sprint
# Set failing gate to null:
# "test": null
```

**Option 3: Bypass for emergency hotfix**
```bash
# WARNING: Only for emergencies
RALPH_BYPASS_HOOKS=1 git commit -m "hotfix: emergency fix"
```

---

### MCP Issues

#### "MCP credentials not found"

**Cause:** PERPLEXITY_API_KEY not set.

**Solution:**
```bash
# Set environment variable
export PERPLEXITY_API_KEY="your-api-key-here"

# Verify
echo $PERPLEXITY_API_KEY

# Make permanent
echo 'export PERPLEXITY_API_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

#### MCP connection test fails

**Cause:** Network issue, invalid credentials, or rate limiting.

**Diagnosis:**
```bash
# Test connection
.claude-plugin/mcp/mcp-test-connection.sh

# Check logs
tail -50 ralph/logs/mcp-usage.log
```

**Solutions:**
- Verify API key is correct
- Check internet connectivity
- Wait if rate limited (resets every minute)
- Verify Perplexity API status

---

### Git Issues

#### "Cannot create branch: branch already exists"

**Cause:** Git branch from previous run still exists.

**Solution:**
```bash
# Option 1: Reuse existing branch
/bmad-ralph:create plugin-sprint --no-branch

# Option 2: Delete old branch
git branch -D ralph/plugin-sprint
# Then create loop normally
```

#### "Uncommitted changes" blocking loop

**Cause:** Working directory has uncommitted changes.

**Solution:**
```bash
# Check status
git status

# Option 1: Commit changes
git add .
git commit -m "feat: save work in progress"

# Option 2: Stash changes
git stash push -m "WIP before loop run"

# Then resume loop
/bmad-ralph:run plugin-sprint
```

---

## FAQ

### General Questions

#### Q: What is Ralph?

**A:** Ralph is an autonomous AI agent loop for Claude Code that implements sprint stories automatically. It runs Claude Code repeatedly until all stories are complete, with quality gates, git workflow, and progress tracking built in.

#### Q: How is this different from just running Claude Code?

**A:** Key differences:
- **Autonomous:** Runs repeatedly until all stories done (you don't have to)
- **Quality gates:** Automatic testing after each story
- **Git workflow:** Atomic commits with conventional messages
- **Progress tracking:** Detailed logs and real-time monitoring
- **Stuck detection:** Alerts when stories need manual help
- **BMAD integration:** Reads sprint-status.yaml directly

#### Q: Does Ralph replace developers?

**A:** No. Ralph is a productivity tool that handles implementation work based on clear requirements. You still need to:
- Define product requirements (PRD)
- Design architecture
- Plan stories and acceptance criteria
- Review and merge pull requests
- Handle complex scenarios Ralph gets stuck on

Think of Ralph as a junior developer that works 24/7 but needs clear instructions.

---

### Setup Questions

#### Q: Can I use Ralph without BMAD Method?

**A:** Ralph is designed for BMAD projects and requires `docs/sprint-status.yaml`. However, you can create this file manually following the BMAD format if you're not using the full BMAD workflow.

Minimum required structure:
```yaml
epics:
  - id: "EPIC-001"
    name: "My Epic"
    stories:
      - id: "STORY-001"
        title: "My Story"
        description: "Story description"
        status: "not-started"
        acceptance_criteria:
          - "First criterion"
          - "Second criterion"
```

#### Q: What if my project doesn't use npm?

**A:** Quality gates are optional and configurable. If you don't use npm:

```bash
# Disable all npm-based gates
/bmad-ralph:config quality-gates
# Set all to null

# Or use custom commands
{
  "qualityGates": {
    "lint": "make lint",
    "build": "make build",
    "test": "make test"
  }
}
```

#### Q: Can I run multiple loops in parallel?

**A:** No. Loops create lock files (`.lock`) to prevent concurrent execution. This prevents git conflicts and ensures clean history.

To run multiple loops:
1. Archive or delete the first loop
2. Create and run the second loop

Or use separate BMAD projects in different directories.

---

### Execution Questions

#### Q: How do I pause a running loop?

**A:** Press `Ctrl+C` in the terminal running the loop. Ralph will:
1. Finish the current iteration gracefully
2. Save progress to progress.txt
3. Remove the lock file
4. Trigger loop-pause hook

Resume with:
```bash
/bmad-ralph:run plugin-sprint
```

#### Q: What happens if Ralph runs out of iterations?

**A:** When max_iterations is reached:
1. Loop stops automatically
2. `loop-complete` hook triggers
3. Progress is saved to progress.txt
4. You'll see exit message: "Max iterations reached"

To continue:
```bash
# Increase max iterations
/bmad-ralph:edit plugin-sprint
# Change "maxIterations": 100 to higher value

# Resume loop
/bmad-ralph:run plugin-sprint
```

#### Q: Can I run Ralph overnight?

**A:** Yes! Ralph is designed for long-running autonomous execution. Best practices:

```bash
# Use nohup to prevent terminal disconnect
nohup /bmad-ralph:run plugin-sprint > ralph-output.log 2>&1 &

# Monitor from another terminal
/bmad-ralph:status plugin-sprint

# Or use tmux/screen
tmux new -s ralph
/bmad-ralph:run plugin-sprint
# Detach: Ctrl+B, then D
# Reattach: tmux attach -t ralph
```

#### Q: How do I skip a story?

**A:** Manually mark it as completed:

```bash
# Edit sprint-status.yaml directly
code docs/sprint-status.yaml

# Find the story and change:
status: "not-started"
# To:
status: "completed"

# Loop will skip this story on next iteration
```

Or use loop editor:
```bash
/bmad-ralph:edit plugin-sprint
# Update story status in config
```

---

### Quality Gate Questions

#### Q: What if quality gates are too strict?

**A:** You can:

**Option 1: Disable specific gates**
```bash
/bmad-ralph:edit plugin-sprint
# Set failing gate to null
```

**Option 2: Adjust gate commands**
```bash
# Example: Lint with auto-fix
{
  "qualityGates": {
    "lint": "npm run lint -- --fix"
  }
}
```

**Option 3: Increase stuck threshold**
```bash
# Give Ralph more attempts before stuck detection
/bmad-ralph:edit plugin-sprint
# Change "stuckThreshold": 3 to 5
```

#### Q: Can I add custom quality gates?

**A:** Currently Ralph supports 4 built-in gates:
- typecheck
- test
- lint
- build

Custom gates are on the roadmap. For now, use pre-commit hooks for additional validation.

---

### Troubleshooting Questions

#### Q: How do I view detailed error logs?

**A:** Multiple log files available:

```bash
# Progress log (iterations, completions)
cat ralph/loops/plugin-sprint/progress.txt

# Hook execution logs
cat .ralph-cache/hooks.log

# Quality gate output
cat .ralph-cache/quality-gate-*.log

# MCP usage logs
cat ralph/logs/mcp-usage.log

# Or use tail for recent entries
tail -50 ralph/loops/plugin-sprint/progress.txt
```

#### Q: Ralph completed a story incorrectly. What do I do?

**A:** Manual correction workflow:

```bash
# 1. Fix the incorrect implementation
git checkout ralph/plugin-sprint
# Make corrections...

# 2. Amend the commit
git add .
git commit --amend --no-edit

# 3. Resume loop
/bmad-ralph:run plugin-sprint
```

Or start fresh:
```bash
# 1. Revert the incorrect commit
git revert <commit-hash>

# 2. Update sprint-status.yaml
# Set story status: "not-started"

# 3. Restart loop
/bmad-ralph:run plugin-sprint --restart
```

#### Q: How do I completely reset a loop?

**A:** Full reset workflow:

```bash
# 1. Delete the loop
/bmad-ralph:delete plugin-sprint --force

# 2. Delete git branch
git branch -D ralph/plugin-sprint

# 3. Reset sprint-status.yaml
# Set all stories status: "not-started"

# 4. Create loop again
/bmad-ralph:create plugin-sprint
```

---

### Advanced Questions

#### Q: Can I customize the prompt template?

**A:** Yes! Each loop has a prompt template in `ralph/loops/<name>/prompt.md`. Edit this file to customize how Claude approaches story implementation.

```bash
# View current prompt
cat ralph/loops/plugin-sprint/prompt.md

# Edit prompt
code ralph/loops/plugin-sprint/prompt.md
```

Changes take effect on next iteration.

#### Q: How do hooks work exactly?

**A:** Hooks are bash scripts that run on lifecycle events:

1. Hook configuration: `.claude-plugin/hooks/hooks.json`
2. Hook scripts: `.claude-plugin/hooks/*.sh`
3. Hook executor: `.claude-plugin/hooks/hook-executor.sh`

Execution flow:
```
Event → Hook Executor → Find matching hooks → Execute in order → Log results
```

See [Hooks System](#hooks-system) for detailed documentation.

#### Q: Can I integrate Ralph with CI/CD?

**A:** Yes! Ralph can run in CI environments:

**GitHub Actions example:**
```yaml
name: Ralph Autonomous Loop
on: workflow_dispatch

jobs:
  ralph:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get install jq
          # Install yq...
      - name: Run Ralph loop
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          /bmad-ralph:run sprint-1 --yes
```

**Important:** Ensure:
- ANTHROPIC_API_KEY is available
- Sufficient CI minutes (loops can be long-running)
- git credentials for commits
- Webhook notifications for monitoring

#### Q: How do I contribute improvements to Ralph?

**A:** Contributions welcome!

1. Fork the repository: https://github.com/snarktank/ralph
2. Create feature branch: `git checkout -b feature/my-improvement`
3. Make changes following existing patterns
4. Test thoroughly with a BMAD project
5. Submit pull request with:
   - Clear description of change
   - Before/after behavior
   - Test results

See `CONTRIBUTING.md` in the repository for detailed guidelines.

---

## How It Works

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Claude Code Plugin                       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Commands   │  │    Hooks     │  │     MCP      │      │
│  │  (13 total)  │  │   (12 types) │  │ (Perplexity) │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                 │                   │              │
│         └─────────────────┼───────────────────┘              │
│                           │                                  │
│                  ┌────────▼────────┐                         │
│                  │  Loop Executor  │                         │
│                  │    (loop.sh)    │                         │
│                  └────────┬────────┘                         │
│                           │                                  │
│  ┌────────────────────────┼────────────────────────┐        │
│  │                        │                        │        │
│  ▼                        ▼                        ▼        │
│ ┌──────────┐      ┌──────────────┐      ┌──────────────┐   │
│ │  Agents  │      │    Skills    │      │  Templates   │   │
│ │ (2 total)│      │  (1 total)   │      │  (configs)   │   │
│ └──────────┘      └──────────────┘      └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │   BMAD Project Files    │
              │                         │
              │  • docs/sprint-status.yaml
              │  • ralph/config.yaml    │
              │  • ralph/loops/         │
              │  • ralph/archive/       │
              └─────────────────────────┘
```

### Execution Flow

1. **User invokes command** (e.g., `/bmad-ralph:run plugin-sprint`)
2. **Command validation** - Check prerequisites, loop exists, not locked
3. **Branch checkout** - Switch to loop's git branch
4. **Lock file creation** - Prevent concurrent runs
5. **Loop execution** (loop.sh):
   ```
   while (stories remaining && iterations < max) {
     a. Read sprint-status.yaml
     b. Find next not-started story
     c. Load story context (architecture, PRD)
     d. Invoke Claude Code with story prompt
     e. Run quality gates (typecheck → test → lint → build)
     f. If gates pass:
        - Git commit with conventional message
        - Update sprint-status.yaml: status = completed
        - Trigger post-story hook
     g. If gates fail:
        - Increment story attempts
        - Check stuck threshold
        - Retry or mark stuck
     h. Append to progress.txt
     i. Increment iteration counter
   }
   ```
6. **Cleanup** - Remove lock file, trigger lifecycle hooks
7. **Exit** - Display summary and next steps

### Story Implementation Process

**Per-story execution:**

```
┌─────────────────────────────────────────────────────────┐
│ 1. Story Context Loading                                │
│    • Read sprint-status.yaml for story details          │
│    • Load acceptance criteria                           │
│    • Read architecture patterns                         │
│    • Read PRD for requirements                          │
└─────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Claude Code Invocation                               │
│    • Inject story prompt with context                   │
│    • Ralph agent or default agent executes              │
│    • Implementation code written                        │
│    • Tests written (if applicable)                      │
└─────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Quality Gates Execution (Sequential)                 │
│    • typecheck: npm run typecheck (if enabled)          │
│    • test: npm test (if enabled)                        │
│    • lint: npm run lint (if enabled)                    │
│    • build: npm run build (if enabled)                  │
│    • Any failure → retry story (up to stuck_threshold)  │
└─────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Git Commit (if gates pass)                           │
│    • Stage all changes: git add .                       │
│    • Pre-commit hook runs (quality gates again)         │
│    • Commit: feat: STORY-XXX - Story Title              │
│    • Co-authored-by: Claude Sonnet 4.5                  │
└─────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────┐
│ 5. State Updates                                        │
│    • Update sprint-status.yaml: status = "completed"    │
│    • Update config.json: storiesCompleted++             │
│    • Append to progress.txt with summary                │
│    • Trigger post-story hook                            │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

**Key files and their roles:**

```
docs/sprint-status.yaml
  ↓ (READ: Story definitions, status)
config.json
  ↓ (READ: Configuration, stats)
prompt.md
  ↓ (READ: Story execution instructions)
loop.sh
  ↓ (EXECUTES: Main loop logic)
Claude Code CLI
  ↓ (INVOKES: Story implementation)
Quality Gates
  ↓ (VALIDATES: Code quality)
Git Commit
  ↓ (PERSISTS: Changes to history)
sprint-status.yaml
  ↑ (WRITE: Update story status)
config.json
  ↑ (WRITE: Update stats)
progress.txt
  ↑ (APPEND: Iteration log)
```

### Autonomous Loop Characteristics

**What makes Ralph autonomous:**

1. **Stateless iterations** - Each Claude invocation starts fresh
2. **Memory persistence** - State stored in files (git, yaml, json, txt)
3. **Progress tracking** - Detailed logs for context continuity
4. **Stuck detection** - Identifies when manual help needed
5. **Quality enforcement** - Automatic validation prevents regressions
6. **Self-monitoring** - Hooks and skills provide optimization feedback

**Loop termination conditions:**

- ✅ All stories completed (`status: "completed"`)
- ❌ Max iterations reached
- ❌ Story stuck (exceeded stuck_threshold)
- ❌ User interruption (Ctrl+C)
- ❌ Critical error (git failure, missing files)

---

## BMAD Method Integration

Ralph is **Phase 5** of the BMAD Method workflow - Autonomous Execution.

### BMAD Workflow Phases

| Phase | Activity | Output | Ralph Integration |
|-------|----------|--------|-------------------|
| 1 | Product Brief | `docs/product-brief-*.md` | Context for agent |
| 2 | PRD | `docs/prd-*.md` | Requirements reference |
| 3 | Architecture | `docs/architecture-*.md` | Patterns to follow |
| 4 | Sprint Planning | `docs/sprint-status.yaml` | **Primary input** |
| **5** | **Autonomous Execution** | **Implemented code** | **Ralph runs here** |
| 6 | Review & Merge | Pull requests | Human review |

### Required BMAD Files

**Minimum required:**
- `docs/sprint-status.yaml` - Sprint stories (REQUIRED)

**Recommended:**
- `docs/prd-*.md` - Product requirements
- `docs/architecture-*.md` - Technical patterns
- `bmad/config.yaml` - BMAD configuration

### Sprint Status Format

Ralph reads stories from `docs/sprint-status.yaml`:

```yaml
epics:
  - id: "EPIC-001"
    name: "User Authentication"
    status: "in_progress"
    stories:
      - id: "STORY-001"
        title: "Implement Login Flow"
        description: |
          Create login form with email/password authentication.

          As a user, I want to log in with email/password so that
          I can access my account.
        status: "not-started"  # Ralph picks this up
        points: 5
        priority: "must-have"
        acceptance_criteria:
          - "Create login form component"
          - "Validate email format"
          - "Hash password before API call"
          - "Store JWT token in localStorage"
          - "Redirect to dashboard on success"
          - "Show error message on failure"
```

**Story status values:**
- `not-started` - Ready for Ralph to implement
- `in-progress` - Currently being worked on
- `completed` - Done (Ralph marks this after successful commit)

### Installing Ralph Agent in BMAD Projects

```bash
# Install Ralph as a BMAD agent
/bmad-ralph:init --install-agent
```

**What this creates:**
- `bmm/agents/ralph.md` - Agent definition
- Updates `docs/bmm-workflow-status.yaml` - Registers Ralph in Phase 5

**BMAD agent definition:**
```yaml
name: ralph
type: execution
phase: 5
description: Autonomous execution agent for sprint stories
capabilities:
  - Story implementation
  - Quality gate execution
  - Git workflow
  - Progress tracking
```

Now BMAD workflows can reference Ralph agent in Phase 5.

### Integration Benefits

**Why use Ralph with BMAD:**

1. **Seamless handoff** - Sprint planning outputs directly to Ralph inputs
2. **Architecture consistency** - Ralph follows patterns from Phase 3 docs
3. **Requirements traceability** - Each commit links to PRD via story ID
4. **Quality enforcement** - Gates ensure Phase 5 output meets standards
5. **Progress visibility** - Real-time monitoring of Phase 5 execution

---

## License

MIT License

Copyright (c) 2026 snarktank

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## References

- [Geoffrey Huntley's Ralph Pattern](https://ghuntley.com/ralph/)
- [Claude Code Documentation](https://claude.com/claude-code)
- [BMAD Method](https://bmad.ai)
- [GitHub Repository](https://github.com/snarktank/ralph)

---

## Support

- **Issues:** https://github.com/snarktank/ralph/issues
- **Discussions:** https://github.com/snarktank/ralph/discussions
- **Email:** noreply@snarktank.dev

---

**Happy autonomous coding!** 🤖
