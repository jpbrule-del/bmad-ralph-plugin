# System Architecture: BMAD Ralph Plugin

**Date:** 2026-01-11
**Architect:** Jean-Philippe Brule
**Version:** 2.0
**Project Type:** claude-code-plugin
**Project Level:** 4 (Major, 35-44 stories)
**Status:** Draft

---

## Document Overview

This document defines the system architecture for converting Ralph from a manually-installed CLI tool to an official Claude Code plugin (`bmad-ralph`). It provides the technical blueprint for implementation, addressing all 7 functional and 5 non-functional requirements from the PRD.

**Related Documents:**
- PRD: `docs/prd-bmad-ralph-plugin-2026-01-11.md`
- v1 Architecture: `docs/architecture-ralph-2026-01-10.md`
- Product Brief: `docs/product-brief-ralph-2026-01-10.md`

---

## Executive Summary

The BMAD Ralph Plugin wraps the existing Ralph CLI (bash-based) with Claude Code's plugin architecture. This creates a **layered architecture** where:

1. **Plugin Layer** - Claude Code-native integration (manifest, commands, hooks, MCP)
2. **Execution Layer** - Existing bash CLI (`packages/cli/`) as the execution engine
3. **Data Layer** - File-based storage (unchanged from v1)

The plugin provides one-click installation via `svrnty-marketplace`, automatic command registration, event hooks, and MCP integration - while preserving all v1 functionality.

**Key Architectural Decisions:**
- **Pattern:** Plugin Adapter over Modular CLI
- **Command Binding:** Markdown commands invoke bash scripts
- **State Management:** File-based (unchanged from v1)
- **Distribution:** Marketplace with auto-update support

---

## Architectural Drivers

These requirements heavily influence architectural decisions:

| Driver | Requirement | Architectural Impact |
|--------|-------------|----------------------|
| **Plugin API Compliance** | FR-001 | Must follow Claude Code plugin schema exactly |
| **Command Namespace** | FR-002 | All commands prefixed with `bmad-ralph:` |
| **Hook System** | FR-005 | Event-driven integration with Claude Code hooks |
| **MCP Protocol** | FR-006 | Standard MCP server configuration |
| **Performance** | NFR-003 | < 500ms command startup, < 100ms hooks |
| **Platform Parity** | NFR-001 | macOS + Linux with identical behavior |

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Claude Code Runtime                               │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      BMAD Ralph Plugin Layer                          │   │
│  │                                                                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │  plugin.json │  │  commands/  │  │   hooks/   │  │  .mcp.json  │  │   │
│  │  │  (manifest)  │  │   (13 .md)  │  │ hooks.json │  │ (perplexity)│  │   │
│  │  └──────┬───────┘  └──────┬──────┘  └──────┬─────┘  └──────┬──────┘  │   │
│  │         │                 │                │               │         │   │
│  │  ┌──────┴─────────────────┴────────────────┴───────────────┴──────┐  │   │
│  │  │                    Plugin API Bridge                           │  │   │
│  │  │        (Command invocation, hook dispatch, MCP routing)        │  │   │
│  │  └────────────────────────────┬──────────────────────────────────┘  │   │
│  │                               │                                      │   │
│  └───────────────────────────────┼──────────────────────────────────────┘   │
│                                  │                                          │
└──────────────────────────────────┼──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Ralph CLI Execution Layer                             │
│                           (packages/cli/)                                    │
│                                                                              │
│  ┌──────────────┐  ┌────────────────┐  ┌────────────────┐  ┌─────────────┐ │
│  │   bin/ralph  │  │  lib/commands/ │  │   lib/core/    │  │ lib/engine/ │ │
│  │ (entry point)│  │  (13 commands) │  │   (utilities)  │  │  (executor) │ │
│  └──────┬───────┘  └───────┬────────┘  └────────┬───────┘  └──────┬──────┘ │
│         │                  │                    │                 │        │
│         └──────────────────┼────────────────────┼─────────────────┘        │
│                            │                    │                          │
│  ┌─────────────────────────┼────────────────────┼─────────────────────────┐│
│  │                    lib/tools/ (External Tool Wrappers)                 ││
│  │    ┌──────┐    ┌──────┐    ┌──────┐    ┌───────────────┐              ││
│  │    │  jq  │    │  yq  │    │  git │    │  claude CLI   │              ││
│  │    └──────┘    └──────┘    └──────┘    └───────────────┘              ││
│  └────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             Data Layer                                       │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │ ralph/config.yaml│  │ ralph/loops/*/   │  │  docs/sprint-    │          │
│  │  (global config) │  │  (loop state)    │  │  status.yaml     │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Architectural Pattern

**Pattern:** Plugin Adapter over Modular CLI

**Rationale:**
- Preserves all v1 CLI functionality (56 stories of validated code)
- Plugin layer provides Claude Code-native UX
- Clean separation allows independent evolution
- Bash execution engine unchanged = zero regression risk

**Trade-offs:**
- ✓ Gain: Reuse proven v1 code, faster development
- ✓ Gain: Plugin can be updated without CLI changes
- ✗ Lose: Two-layer indirection (minimal performance impact)

---

## Technology Stack

### Plugin Layer

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Manifest | JSON (plugin.json) | Claude Code plugin API standard |
| Commands | Markdown (.md) | Claude Code command format |
| Hooks | JSON (hooks.json) | Claude Code hook schema |
| MCP Config | JSON (.mcp.json) | MCP standard configuration |
| Skills | Markdown (SKILL.md) | Claude Code skill format |
| Agents | Markdown (.md) | Claude Code agent format |

### Execution Layer (Unchanged from v1)

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Runtime | Bash 4.0+ | v1 compatibility |
| JSON Processing | jq 1.6+ | v1 compatibility |
| YAML Processing | yq 4.x (Mike Farah) | v1 compatibility |
| Version Control | Git 2.x | v1 compatibility |
| AI Engine | Claude Code CLI | v1 compatibility |

### External Integrations

| Integration | Protocol | Purpose |
|-------------|----------|---------|
| Perplexity | MCP | Research during loop execution |
| svrnty-marketplace | HTTP/Git | Plugin distribution |
| Claude Code | Plugin API | Command, hook, skill registration |

---

## System Components

### Component 1: Plugin Manifest (plugin.json)

**Purpose:** Declares plugin identity, capabilities, and requirements to Claude Code

**Responsibilities:**
- Plugin metadata (name, version, description, author)
- Dependency declarations (jq, yq, git)
- Permission requests (file system, process execution, network)
- Command registrations (13 commands)
- Hook registrations (4 hook types)
- MCP server declarations

**Schema:**
```json
{
  "name": "bmad-ralph",
  "version": "2.0.0",
  "description": "Autonomous AI agent loop for BMAD Method",
  "author": {
    "name": "Jean-Philippe Brule",
    "email": "..."
  },
  "claude_code_version": ">=1.0.0",

  "dependencies": {
    "system": {
      "jq": ">=1.6",
      "yq": ">=4.0",
      "git": ">=2.0"
    }
  },

  "permissions": {
    "filesystem": {
      "read": ["ralph/", "docs/", "bmad/"],
      "write": ["ralph/"]
    },
    "process": {
      "execute": ["jq", "yq", "git", "npm", "node"]
    },
    "network": {
      "mcp": ["perplexity"]
    }
  },

  "commands": {
    "directory": "commands/",
    "namespace": "bmad-ralph"
  },

  "hooks": {
    "config": "hooks/hooks.json"
  },

  "skills": {
    "directory": "skills/"
  },

  "agents": {
    "directory": "agents/"
  },

  "mcp": {
    "config": ".mcp.json"
  }
}
```

**FRs Addressed:** FR-001

---

### Component 2: Command Definitions (.claude-plugin/commands/)

**Purpose:** Define 13 slash commands that invoke Ralph CLI

**Structure:**
```
commands/
├── init.md           → /bmad-ralph:init
├── create.md         → /bmad-ralph:create
├── run.md            → /bmad-ralph:run
├── status.md         → /bmad-ralph:status
├── list.md           → /bmad-ralph:list
├── show.md           → /bmad-ralph:show
├── edit.md           → /bmad-ralph:edit
├── clone.md          → /bmad-ralph:clone
├── delete.md         → /bmad-ralph:delete
├── archive.md        → /bmad-ralph:archive
├── unarchive.md      → /bmad-ralph:unarchive
├── config.md         → /bmad-ralph:config
└── feedback-report.md → /bmad-ralph:feedback-report
```

**Command File Format:**
```markdown
You are executing the **Ralph {Command}** command.

## Command Overview

**Purpose:** {Brief description}
**Agent:** Ralph CLI

---

## Execution

Run the ralph CLI command:

\`\`\`bash
ralph {command} {args}
\`\`\`

### Options

- `--flag` - Description

### Examples

\`\`\`bash
ralph {command} example-1
ralph {command} example-2 --flag
\`\`\`

### What It Does

1. Step 1
2. Step 2
3. Step 3

### Related Commands

- `ralph other-command` - Description
```

**Invocation Pattern:**
```
User types: /bmad-ralph:create my-loop
Claude Code: Reads commands/create.md
Claude Code: Understands it should run `ralph create my-loop`
Claude Code: Executes via Bash tool
```

**FRs Addressed:** FR-002

---

### Component 3: Skills System (.claude-plugin/skills/)

**Purpose:** Auto-invoked skills for intelligent assistance

**Structure:**
```
skills/
└── loop-optimization/
    └── SKILL.md
```

**Skill Invocation:**
- Triggered during `bmad-ralph:run` command
- Analyzes loop performance patterns
- Suggests optimizations proactively

**SKILL.md Format:**
```markdown
---
name: Loop Optimization
triggers:
  - command: bmad-ralph:run
  - context: loop_running
---

# Loop Optimization Skill

When a user runs a Ralph loop, analyze these factors:

1. **Iteration Efficiency**
   - Check iterations per story
   - Flag if > 5 iterations consistently

2. **Stuck Patterns**
   - Analyze progress.txt for stuck indicators
   - Suggest threshold adjustments

3. **Quality Gate Performance**
   - Track gate pass/fail rates
   - Recommend gate configuration changes

## Proactive Suggestions

Offer suggestions when:
- Story takes > 3 iterations
- Same error appears multiple times
- Quality gates fail repeatedly
```

**FRs Addressed:** FR-003

---

### Component 4: Agent Definitions (.claude-plugin/agents/)

**Purpose:** Specialized sub-agents for Ralph operations

**Structure:**
```
agents/
├── ralph-agent.md      # Main execution agent
└── loop-monitor.md     # Status monitoring agent
```

**ralph-agent.md:**
```markdown
---
name: Ralph Execution Agent
capabilities:
  - Story implementation
  - Quality gate execution
  - Git operations
  - BMAD compliance
---

# Ralph Execution Agent

You are a specialized agent for executing BMAD stories autonomously.

## Core Knowledge

- BMAD Method Phase 4/5 workflow
- Ralph loop execution patterns
- Quality gate best practices
- Git commit conventions

## Constraints

- Only modify files related to current story
- Always run quality gates after changes
- Follow BMAD commit message format
- Never skip stuck detection

## Execution Flow

1. Read current story from sprint-status.yaml
2. Understand acceptance criteria
3. Implement changes
4. Run quality gates
5. Commit if passing
6. Update progress.txt
```

**FRs Addressed:** FR-004

---

### Component 5: Hooks System (.claude-plugin/hooks/)

**Purpose:** Event-driven automation for loop lifecycle

**hooks.json Schema:**
```json
{
  "version": "1.0",
  "hooks": [
    {
      "name": "pre-commit",
      "event": "before_commit",
      "handler": "scripts/pre-commit.sh",
      "timeout_ms": 30000,
      "fail_action": "block",
      "config": {
        "run_quality_gates": true,
        "bypass_flag": "--skip-hooks"
      }
    },
    {
      "name": "post-story",
      "event": "story_completed",
      "handler": "scripts/post-story.sh",
      "timeout_ms": 5000,
      "fail_action": "warn",
      "config": {
        "update_progress": true,
        "notify": false
      }
    },
    {
      "name": "loop-lifecycle",
      "events": ["loop_start", "loop_pause", "loop_resume", "loop_complete"],
      "handler": "scripts/loop-lifecycle.sh",
      "timeout_ms": 5000,
      "fail_action": "log"
    },
    {
      "name": "stuck-detection",
      "event": "iteration_complete",
      "handler": "scripts/stuck-detection.sh",
      "timeout_ms": 2000,
      "fail_action": "alert",
      "config": {
        "threshold": 3,
        "action": "pause_and_notify"
      }
    }
  ]
}
```

**Hook Scripts (in packages/cli/):**
```
packages/cli/
└── scripts/
    ├── pre-commit.sh
    ├── post-story.sh
    ├── loop-lifecycle.sh
    └── stuck-detection.sh
```

**Event Flow:**
```
Event Occurs (e.g., commit attempted)
         │
         ▼
Claude Code Hook Dispatcher
         │
         ▼
Read hooks.json configuration
         │
         ▼
Execute handler script (bash)
         │
         ├──▶ Success → Continue operation
         │
         └──▶ Failure → Apply fail_action (block/warn/log/alert)
```

**FRs Addressed:** FR-005

---

### Component 6: MCP Integration (.claude-plugin/.mcp.json)

**Purpose:** External service integration via Model Context Protocol

**.mcp.json Schema:**
```json
{
  "version": "1.0",
  "servers": {
    "perplexity": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-perplexity"],
      "env": {
        "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}"
      },
      "capabilities": {
        "search": true,
        "research": true
      },
      "retry": {
        "max_attempts": 3,
        "backoff_ms": 1000
      },
      "timeout_ms": 30000
    }
  }
}
```

**Usage in Ralph:**
- Agent can call `perplexity_search` during story implementation
- Research external APIs, libraries, patterns
- Validate implementation approaches

**Credential Handling:**
- API keys stored in environment variables
- Never logged or written to files
- Validated on plugin load

**FRs Addressed:** FR-006

---

### Component 7: Marketplace Distribution

**Purpose:** Enable one-click installation via marketplace

**marketplace.json:**
```json
{
  "name": "bmad-ralph",
  "display_name": "BMAD Ralph - Autonomous AI Agent Loop",
  "version": "2.0.0",
  "description": "Execute BMAD stories autonomously while you sleep",
  "category": "automation",
  "tags": ["bmad", "autonomous", "loop", "story-execution"],

  "repository": "https://github.com/snarktank/ralph",
  "homepage": "https://github.com/snarktank/ralph",
  "documentation": "https://github.com/snarktank/ralph#readme",

  "screenshots": [
    "assets/screenshot-status.png",
    "assets/screenshot-run.png"
  ],

  "compatibility": {
    "claude_code": ">=1.0.0",
    "platforms": ["darwin", "linux"]
  },

  "installation": {
    "post_install": "scripts/verify-install.sh",
    "dependencies_check": true
  }
}
```

**Marketplace Repository (svrnty-marketplace):**
```
svrnty-marketplace/
├── index.json              # Plugin index
├── plugins/
│   └── bmad-ralph/
│       ├── manifest.json   # Plugin metadata
│       ├── versions/
│       │   ├── 2.0.0.json
│       │   └── 2.0.1.json
│       └── assets/
│           └── screenshots/
└── README.md
```

**Installation Flow:**
```
User: /plugin install svrnty-marketplace/bmad-ralph
         │
         ▼
Claude Code: Fetch plugin index from marketplace
         │
         ▼
Claude Code: Download plugin package
         │
         ▼
Claude Code: Verify dependencies (jq, yq, git)
         │
         ▼
Claude Code: Register commands, hooks, MCP
         │
         ▼
Claude Code: Run post_install verification
         │
         ▼
User: Ready! Type /bmad-ralph: to see commands
```

**FRs Addressed:** FR-007

---

## Data Architecture

### Data Model (Unchanged from v1)

The plugin layer adds no new data entities. All state remains in the v1 file-based format:

```
ralph/
├── config.yaml           # Global configuration
├── loops/
│   └── <loop-name>/
│       ├── prd.json      # Loop config + execution metadata
│       ├── prompt.md     # Claude context
│       └── progress.txt  # Iteration log
└── archive/
    └── <date>-<loop-name>/
        ├── (loop files)
        └── feedback.json # Archive feedback
```

### Plugin-Specific Data

The plugin layer adds only configuration metadata:

```
.claude-plugin/
├── plugin.json           # Plugin manifest (read-only)
├── marketplace.json      # Marketplace listing (read-only)
├── commands/*.md         # Command definitions (read-only)
├── skills/*/SKILL.md     # Skill definitions (read-only)
├── agents/*.md           # Agent definitions (read-only)
├── hooks/hooks.json      # Hook configuration (read-only)
└── .mcp.json             # MCP configuration (read-only)
```

**Note:** All plugin files are read-only after installation. No plugin state is written during execution.

### Data Flow

```
1. COMMAND INVOCATION:
   User input ──▶ Claude Code ──▶ Read command .md
                        │
                        ▼
              Parse command intent
                        │
                        ▼
              Execute bash command ──▶ packages/cli/bin/ralph
                        │
                        ▼
              CLI reads/writes ──▶ ralph/loops/*, docs/sprint-status.yaml

2. HOOK EXECUTION:
   Event occurs ──▶ Claude Code Hook Dispatcher
                        │
                        ▼
              Read hooks.json ──▶ Find matching hook
                        │
                        ▼
              Execute handler script ──▶ packages/cli/scripts/*
                        │
                        ▼
              Return result ──▶ Apply fail_action

3. MCP USAGE:
   Agent needs research ──▶ Claude Code MCP Router
                        │
                        ▼
              Route to perplexity server
                        │
                        ▼
              Execute search/research
                        │
                        ▼
              Return results to agent
```

---

## Command Interface Design

### Namespace Convention

All commands use the `bmad-ralph:` namespace:

```
/bmad-ralph:init           # Initialize Ralph
/bmad-ralph:create <name>  # Create loop
/bmad-ralph:run <name>     # Execute loop
/bmad-ralph:status <name>  # Monitor loop
/bmad-ralph:list           # List loops
/bmad-ralph:show <name>    # Show loop details
/bmad-ralph:edit <name>    # Edit loop config
/bmad-ralph:clone <s> <d>  # Clone loop
/bmad-ralph:delete <name>  # Delete loop
/bmad-ralph:archive <name> # Archive loop
/bmad-ralph:unarchive <n>  # Restore loop
/bmad-ralph:config         # Manage config
/bmad-ralph:feedback-report # View analytics
```

### Command-to-CLI Mapping

| Slash Command | CLI Command | Primary FR |
|---------------|-------------|------------|
| `/bmad-ralph:init` | `ralph init` | FR-002 |
| `/bmad-ralph:create <name>` | `ralph create <name>` | FR-002 |
| `/bmad-ralph:run <name>` | `ralph run <name>` | FR-002 |
| `/bmad-ralph:status <name>` | `ralph status <name>` | FR-002 |
| `/bmad-ralph:list` | `ralph list` | FR-002 |
| `/bmad-ralph:show <name>` | `ralph show <name>` | FR-002 |
| `/bmad-ralph:edit <name>` | `ralph edit <name>` | FR-002 |
| `/bmad-ralph:clone <s> <d>` | `ralph clone <s> <d>` | FR-002 |
| `/bmad-ralph:delete <name>` | `ralph delete <name>` | FR-002 |
| `/bmad-ralph:archive <name>` | `ralph archive <name>` | FR-002 |
| `/bmad-ralph:unarchive <n>` | `ralph unarchive <n>` | FR-002 |
| `/bmad-ralph:config` | `ralph config` | FR-002 |
| `/bmad-ralph:feedback-report` | `ralph feedback-report` | FR-002 |

### Argument Parsing

Commands receive arguments through Claude Code's natural language processing:

```
User: /bmad-ralph:create my-sprint --epic EPIC-001 --yes

Claude Code parses:
  - command: create
  - name: my-sprint
  - --epic: EPIC-001
  - --yes: true

Executes:
  ralph create my-sprint --epic EPIC-001 --yes
```

---

## Non-Functional Requirements Coverage

### NFR-001: Platform Support

**Requirement:** macOS and Linux support

**Solution:**
- Plugin manifest declares platform compatibility
- All hook scripts use POSIX-compliant bash
- No platform-specific code in plugin layer
- v1 CLI already validated on both platforms

**Validation:**
- Test installation on macOS (Intel + Apple Silicon)
- Test installation on Ubuntu 20.04+
- Verify all 13 commands work identically

---

### NFR-002: Claude Code Compatibility

**Requirement:** Target latest stable Claude Code only

**Solution:**
- pin `claude_code_version: ">=1.0.0"` in manifest
- Use only documented, stable plugin APIs
- No deprecated API usage
- Version check during installation

**Validation:**
- Test with current stable Claude Code
- Monitor Claude Code release notes for API changes

---

### NFR-003: Performance

**Requirement:** < 500ms command startup, < 100ms hooks

**Solution:**

**Command Startup:**
- Markdown command files are small (< 5KB each)
- No heavy parsing on command load
- CLI execution is the main latency
- v1 CLI already optimized for < 2s startup

**Hook Processing:**
- hooks.json is parsed once on plugin load
- Hook scripts are lightweight bash
- Timeout enforcement prevents runaway hooks
- Async execution where possible

**Measurements:**
| Operation | Target | Implementation |
|-----------|--------|----------------|
| Command parse | < 50ms | Small .md files |
| Hook dispatch | < 20ms | Pre-parsed hooks.json |
| Hook execution | < 100ms | Lightweight scripts |
| MCP routing | < 50ms | Standard MCP protocol |

**Validation:**
- Benchmark command startup time
- Measure hook execution latency
- Profile MCP request overhead

---

### NFR-004: Documentation

**Requirement:** Comprehensive documentation

**Solution:**

**Self-Documenting Commands:**
- Each command .md file includes examples
- Related commands section for discoverability
- Options documented inline

**README Sections:**
1. Quick Start (one-click install)
2. Prerequisites
3. All Commands Reference
4. Hooks Configuration Guide
5. MCP Integration Guide
6. Troubleshooting
7. FAQ

**Inline Help:**
- `/bmad-ralph:help` shows all commands
- Each command has `--help` support
- Error messages include recovery steps

**Validation:**
- Documentation review checklist
- Test all examples work
- User feedback on clarity

---

### NFR-005: Security

**Requirement:** No sensitive data, secure MCP credentials

**Solution:**

**No Sensitive Data in Plugin Files:**
- All .md, .json files are declarative
- No hardcoded secrets
- No credentials in version control

**MCP Credential Handling:**
```json
{
  "env": {
    "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}"
  }
}
```
- API keys read from environment only
- Never written to disk
- Never logged

**Permission Declarations:**
- Explicit file system permissions
- Explicit process execution permissions
- User sees permissions during install

**Sandboxed Hook Execution:**
- Hooks run with limited permissions
- Timeout enforcement
- No network access from hooks (except MCP)

**Validation:**
- Grep for hardcoded secrets
- Verify no credentials in logs
- Test permission boundaries

---

## Security Architecture

### Threat Model

| Threat | Risk Level | Mitigation |
|--------|------------|------------|
| Credential exposure | Medium | Environment variables only |
| Command injection | Low | Input validation in CLI |
| Malicious hook | Low | Hook scripts in package, not user-editable |
| MCP server compromise | Low | Use official MCP servers only |

### Permission Model

**File System:**
```json
"filesystem": {
  "read": ["ralph/", "docs/", "bmad/"],
  "write": ["ralph/"]
}
```
- Read access to BMAD files (read-only)
- Write access only to ralph/ directory

**Process Execution:**
```json
"process": {
  "execute": ["jq", "yq", "git", "npm", "node"]
}
```
- Limited to known, required tools
- No arbitrary command execution

**Network:**
```json
"network": {
  "mcp": ["perplexity"]
}
```
- Only MCP servers, no arbitrary HTTP

### Secure Defaults

- All hooks have timeouts
- Default fail_action is "warn" not "ignore"
- Bypass flags require explicit use
- Confirmation required for destructive operations

---

## Directory Structure

### Complete Plugin Structure

```
ralph/                                  # Repository root
├── .claude-plugin/                     # Plugin layer (NEW)
│   ├── plugin.json                     # Plugin manifest
│   ├── marketplace.json                # Marketplace listing
│   ├── commands/                       # Command definitions
│   │   ├── init.md
│   │   ├── create.md
│   │   ├── run.md
│   │   ├── status.md
│   │   ├── list.md
│   │   ├── show.md
│   │   ├── edit.md
│   │   ├── clone.md
│   │   ├── delete.md
│   │   ├── archive.md
│   │   ├── unarchive.md
│   │   ├── config.md
│   │   └── feedback-report.md
│   ├── skills/
│   │   └── loop-optimization/
│   │       └── SKILL.md
│   ├── agents/
│   │   ├── ralph-agent.md
│   │   └── loop-monitor.md
│   ├── hooks/
│   │   └── hooks.json
│   └── .mcp.json
├── packages/cli/                       # Execution layer (EXISTING)
│   ├── bin/ralph                       # CLI entry point
│   ├── lib/
│   │   ├── commands/                   # Command implementations
│   │   ├── core/                       # Utilities
│   │   ├── engine/                     # Loop executor
│   │   ├── dashboard/                  # Status UI
│   │   ├── feedback/                   # Feedback system
│   │   ├── generator/                  # File generators
│   │   └── tools/                      # External tool wrappers
│   ├── scripts/                        # Hook scripts (NEW)
│   │   ├── pre-commit.sh
│   │   ├── post-story.sh
│   │   ├── loop-lifecycle.sh
│   │   └── stuck-detection.sh
│   ├── skills/ralph/                   # Legacy skills (migrate to plugin)
│   ├── templates/                      # File templates
│   └── package.json
├── docs/                               # Documentation
│   ├── prd-bmad-ralph-plugin-*.md
│   ├── architecture-bmad-ralph-plugin-*.md
│   └── ...
├── install.sh                          # Installation script
└── README.md                           # Main documentation
```

---

## Requirements Traceability

### Functional Requirements

| FR ID | FR Name | Primary Component(s) |
|-------|---------|----------------------|
| FR-001 | Plugin Manifest & Structure | .claude-plugin/plugin.json |
| FR-002 | Command Migration | .claude-plugin/commands/*.md |
| FR-003 | Skills Integration | .claude-plugin/skills/ |
| FR-004 | Agent System | .claude-plugin/agents/ |
| FR-005 | Hooks System | .claude-plugin/hooks/hooks.json |
| FR-006 | MCP Integration | .claude-plugin/.mcp.json |
| FR-007 | Marketplace Distribution | marketplace.json, svrnty-marketplace |

### Non-Functional Requirements

| NFR ID | NFR Name | Solution |
|--------|----------|----------|
| NFR-001 | Platform Support | POSIX-compliant plugin + CLI |
| NFR-002 | Claude Code Compatibility | Version pinning, stable APIs |
| NFR-003 | Performance | Lightweight files, timeouts |
| NFR-004 | Documentation | Self-documenting commands, README |
| NFR-005 | Security | Env credentials, permissions, sandboxing |

---

## Trade-offs & Decision Log

### Decision 1: Plugin Adapter vs. Full Rewrite

**Options:**
- A) Wrap existing CLI with plugin layer (chosen)
- B) Rewrite all functionality as pure plugin

**Decision:** Option A - Plugin Adapter

**Trade-offs:**
- ✓ Gain: Preserve 56 stories of validated code
- ✓ Gain: Faster development (~60% faster)
- ✓ Gain: Lower regression risk
- ✗ Lose: Two-layer architecture complexity
- ✗ Lose: CLI must be available at runtime

**Rationale:** The v1 CLI has been thoroughly tested through 86 iterations. Preserving it minimizes risk and development time.

---

### Decision 2: Namespace Choice

**Options:**
- A) `ralph:` (simple)
- B) `bmad-ralph:` (chosen - scoped to BMAD ecosystem)
- C) `svrnty-ralph:` (vendor prefix)

**Decision:** Option B - `bmad-ralph:`

**Trade-offs:**
- ✓ Gain: Clear BMAD ecosystem association
- ✓ Gain: Avoids conflicts with other "ralph" plugins
- ✗ Lose: Slightly longer to type

**Rationale:** Ralph is BMAD Phase 5; the namespace should reflect this relationship.

---

### Decision 3: Hook Execution Model

**Options:**
- A) Inline JavaScript in hooks.json
- B) External bash scripts (chosen)
- C) WebAssembly modules

**Decision:** Option B - External Bash Scripts

**Trade-offs:**
- ✓ Gain: Reuse existing CLI code
- ✓ Gain: Familiar bash debugging
- ✓ Gain: Easy to update without plugin rebuild
- ✗ Lose: Requires bash availability

**Rationale:** Consistency with v1 CLI (all bash) and easier maintenance.

---

### Decision 4: MCP Server Selection

**Options:**
- A) Multiple MCP servers (Perplexity, web-fetch, etc.)
- B) Perplexity only (chosen)
- C) No MCP integration

**Decision:** Option B - Perplexity Only

**Trade-offs:**
- ✓ Gain: Focused, high-value integration
- ✓ Gain: Simpler configuration
- ✗ Lose: Less flexibility

**Rationale:** Perplexity covers primary research needs. Other MCPs can be added later.

---

## Implementation Phases

### Phase 1: Foundation (EPIC-001)

- Create `.claude-plugin/` directory structure
- Implement `plugin.json` manifest
- Dependency verification system
- Configuration schema
- Permission declarations

### Phase 2: Command Migration (EPIC-002)

- Create all 13 command .md files
- Verify command invocation works
- Test all flags and options
- Validate output formatting

### Phase 3: Enhancements (EPIC-003, 004, 005)

- Implement loop-optimization skill
- Create ralph-agent and loop-monitor agents
- Implement 4 hook types
- Configure Perplexity MCP server

### Phase 4: Distribution (EPIC-006, 007)

- Create marketplace.json
- Setup svrnty-marketplace repository
- Implement version management
- Write comprehensive documentation
- Launch validation testing

---

## Validation Checklist

### Plugin Structure
- [ ] plugin.json validates against Claude Code schema
- [ ] All 13 command .md files present
- [ ] Hooks.json schema valid
- [ ] MCP.json configuration valid

### Command Functionality
- [ ] All 13 commands invoke correct CLI commands
- [ ] All flags pass through correctly
- [ ] Error handling works appropriately
- [ ] Output formatting preserved

### Hook System
- [ ] Pre-commit hook blocks on failure
- [ ] Post-story hook updates progress
- [ ] Loop lifecycle hooks fire correctly
- [ ] Stuck detection triggers at threshold

### MCP Integration
- [ ] Perplexity search works
- [ ] Perplexity research works
- [ ] Credential handling secure
- [ ] Error handling graceful

### Platform Testing
- [ ] macOS installation successful
- [ ] Linux installation successful
- [ ] All commands work on both platforms
- [ ] Performance targets met

### Documentation
- [ ] README complete
- [ ] All commands documented
- [ ] Hooks guide complete
- [ ] Troubleshooting section complete

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0 | 2026-01-11 | Jean-Philippe Brule | Plugin architecture for v2 |

---

## Next Steps

### Sprint Planning

Run `/bmad:sprint-planning` to:
- Break epics into sprint iterations
- Estimate story complexity
- Assign implementation order
- Begin EPIC-001: Plugin Foundation

**Implementation Priorities:**
1. Plugin manifest (blocking for all other work)
2. Command migration (core functionality)
3. Hooks system (automation value)
4. MCP integration (enhancement)
5. Marketplace distribution (launch requirement)
6. Documentation (launch requirement)

---

**This document was created using BMAD Method v6 - Phase 3 (Solutioning)**

*To continue: Run `/workflow-status` to see your progress and next recommended workflow.*
