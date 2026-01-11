# System Architecture: ralph

**Date:** 2026-01-10
**Architect:** Jean-Philippe Brule
**Version:** 1.0
**Project Type:** cli-tool
**Project Level:** 3 (Complex, 12-40 stories)
**Status:** Draft

---

## Document Overview

This document defines the system architecture for ralph, a BMAD Phase 4/5 autonomous execution CLI tool. It provides the technical blueprint for implementation, addressing all 41 functional and 21 non-functional requirements from the PRD.

**Related Documents:**
- Product Requirements Document: `docs/prd-ralph-2026-01-10.md`
- Product Brief: `docs/product-brief-ralph-2026-01-10.md`

---

## Executive Summary

Ralph is a modular bash CLI tool that automates story implementation after BMAD sprint planning. The architecture follows a command-router pattern with clear separation between commands, core utilities, and external tool integrations. All state is file-based using YAML and JSON, with atomic write operations ensuring reliability. The system integrates with BMAD's sprint-status.yaml and executes stories autonomously via Claude Code CLI.

**Key Architectural Decisions:**
- **Pattern:** Modular Bash CLI with command routing
- **Storage:** File-based (YAML/JSON, no database)
- **Dependencies:** jq, yq, git, claude CLI
- **Platforms:** macOS 12+, Linux (Ubuntu 20.04+, Debian 11+)

---

## Architectural Drivers

These NFRs heavily influence architectural decisions:

| Driver | NFR | Architectural Impact |
|--------|-----|----------------------|
| **State Persistence** | NFR-010, NFR-011 | Atomic file operations, crash recovery |
| **Cross-Platform** | NFR-030, NFR-031 | POSIX-compliant bash, no OS-specific commands |
| **External Tool Integration** | NFR-033, NFR-034 | Abstraction layer for jq, yq, git, claude |
| **Terminal UI** | NFR-002, NFR-021 | ANSI escapes, tput, terminal dimension handling |
| **File I/O Efficiency** | NFR-003, NFR-011 | Append-only logging, temp-file-rename pattern |

---

## System Overview

### High-Level Architecture

Ralph follows a **Modular Bash CLI** architecture with clear component boundaries:

```
┌─────────────────────────────────────────────────────────────────────┐
│                           ralph (entry point)                        │
│                                                                      │
│  ┌─────────────┐   ┌──────────────┐   ┌──────────────────────────┐ │
│  │   Commands   │   │    Core      │   │       External Tools     │ │
│  │             │   │              │   │                          │ │
│  │ init        │   │ config.sh    │   │  ┌─────┐  ┌─────┐       │ │
│  │ create      │──▶│ state.sh     │──▶│  │ jq  │  │ yq  │       │ │
│  │ list        │   │ utils.sh     │   │  └─────┘  └─────┘       │ │
│  │ run         │   │ validation.sh│   │                          │ │
│  │ status      │   │              │   │  ┌─────┐  ┌───────────┐ │ │
│  │ archive     │   └──────────────┘   │  │ git │  │ claude    │ │ │
│  │ delete      │                      │  └─────┘  └───────────┘ │ │
│  └─────────────┘                      └──────────────────────────┘ │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                        Data Layer                             │   │
│  │                                                               │   │
│  │  ralph/config.yaml    ralph/loops/<name>/    docs/sprint-    │   │
│  │  (global config)      prd.json, loop.sh      status.yaml     │   │
│  │                       prompt.md, progress    (BMAD source)   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Architecture Diagram

```
                              ┌──────────────────┐
                              │   User Terminal  │
                              └────────┬─────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │   bin/ralph      │
                              │  (Entry Point)   │
                              └────────┬─────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
           ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
           │  lib/commands │  │   lib/core    │  │  lib/engine   │
           │               │  │               │  │               │
           │ init.sh       │  │ config.sh     │  │ executor.sh   │
           │ create.sh     │  │ state.sh      │  │ detector.sh   │
           │ list.sh       │  │ validation.sh │  │ gates.sh      │
           │ run.sh        │  │ output.sh     │  │ stats.sh      │
           │ status.sh     │  │ prompts.sh    │  └───────┬───────┘
           │ archive.sh    │  │ progress.sh   │          │
           │ delete.sh     │  └───────────────┘          │
           └───────────────┘                             │
                    │                                    │
                    └──────────────┬─────────────────────┘
                                   │
                                   ▼
                          ┌───────────────┐
                          │  lib/tools    │
                          │               │
                          │ json.sh (jq)  │
                          │ yaml.sh (yq)  │
                          │ git.sh        │
                          │ claude.sh     │
                          └───────┬───────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
              ┌──────────┐  ┌──────────┐  ┌──────────┐
              │   jq     │  │   yq     │  │  claude  │
              │          │  │          │  │   CLI    │
              └──────────┘  └──────────┘  └──────────┘
```

### Architectural Pattern

**Pattern:** Modular Bash CLI with Command Routing

**Rationale:**
- Bash is mandated by PRD constraints
- Modular structure enables testability and maintainability
- Command routing pattern is standard for CLI tools (git-style subcommands)
- Single entry point with sourced modules keeps things organized
- Clear separation between commands, core utilities, and external integrations

---

## Technology Stack

### Shell / Runtime

**Choice:** Bash 4.0+ (POSIX-compatible subset)

**Rationale:**
- Mandated by PRD (bash-only constraint)
- Available on macOS 12+ and all Linux distributions
- POSIX subset ensures macOS/Linux compatibility

**Trade-offs:**
- ✓ No compilation, universal availability, easy distribution
- ✗ Limited data structures, no native JSON/YAML, performance ceiling

---

### Data Processing

**Choice:** jq 1.6+ (JSON) + yq 4.x (YAML, Mike Farah's version)

**Rationale:**
- Standard tools for JSON/YAML manipulation in shell scripts
- Both support complex queries needed for sprint-status.yaml parsing
- Available via Homebrew (macOS) and apt/yum (Linux)

**Trade-offs:**
- ✓ Powerful querying, standard tools, well-documented
- ✗ Two external dependencies

---

### Version Control

**Choice:** Git 2.x

**Rationale:** Required for branch creation (FR-016), already present in target environments.

---

### AI Execution Engine

**Choice:** Claude Code CLI

**Rationale:**
- Mandated by PRD (core execution dependency)
- Provides autonomous execution capability via `claude --print --dangerously-skip-permissions`

---

### Terminal UI

**Choice:** ANSI Escape Sequences + tput

**Rationale:**
- tput provides terminal-agnostic cursor control
- ANSI escapes work in 99% of modern terminals
- No additional dependencies

---

### Testing Framework

**Choice:** Bats (Bash Automated Testing System)

**Rationale:** Standard testing framework for bash scripts, TAP-compliant output, simple syntax.

---

### Development Tools

| Tool | Purpose |
|------|---------|
| ShellCheck | Static analysis / linting |
| Bats | Unit and integration testing |
| Git | Version control |
| Make | Build orchestration |

---

## System Components

### Component: Entry Point (bin/ralph)

**Purpose:** Single entry point, command routing, global initialization

**Responsibilities:**
- Parse command-line arguments
- Route to appropriate command handler
- Check dependencies (jq, yq, git, claude)
- Set global variables (colors, paths)
- Handle `--help` and `--version` flags

**FRs Addressed:** FR-002, FR-003

---

### Component: Commands Module (lib/commands/)

**Purpose:** Individual command implementations

| File | Command | FRs |
|------|---------|-----|
| init.sh | `ralph init` | FR-001 |
| create.sh | `ralph create <name>` | FR-010 - FR-019 |
| list.sh | `ralph list` | FR-020, FR-054 |
| show.sh | `ralph show <name>` | FR-022, FR-055 |
| run.sh | `ralph run <name>` | FR-030 - FR-039 |
| status.sh | `ralph status <name>` | FR-040 - FR-049 |
| archive.sh | `ralph archive <name>` | FR-050 - FR-058 |
| delete.sh | `ralph delete <name>` | FR-021 |

---

### Component: Core Utilities (lib/core/)

**Purpose:** Shared functionality across all commands

| File | Purpose | Key NFRs |
|------|---------|----------|
| config.sh | Load/save configuration | FR-065 |
| state.sh | Atomic state management | NFR-010, NFR-011 |
| validation.sh | Input validation | NFR-012, NFR-013 |
| output.sh | Colored output, formatting | NFR-021, NFR-022 |
| prompts.sh | User prompts, confirmations | NFR-024 |
| progress.sh | Progress indicators | NFR-023 |

---

### Component: External Tools Wrapper (lib/tools/)

**Purpose:** Abstraction layer for external dependencies

| File | Tool | Functions |
|------|------|-----------|
| json.sh | jq | json_get, json_set, json_query |
| yaml.sh | yq | yaml_get, yaml_set, yaml_query |
| git.sh | git | git_branch, git_checkout, git_status |
| claude.sh | claude | claude_run |

**FRs Addressed:** FR-011, FR-031, FR-016

---

### Component: Loop Engine (lib/engine/)

**Purpose:** Core execution logic for running loops

| File | Purpose | FRs |
|------|---------|-----|
| executor.sh | Main iteration loop | FR-030, FR-031 |
| detector.sh | Story completion/stuck detection | FR-032, FR-033 |
| gates.sh | Quality gate runner | FR-034 |
| stats.sh | Statistics tracking | FR-037 |

---

### Component: Dashboard (lib/dashboard/)

**Purpose:** Real-time monitoring terminal UI

| File | Purpose | FRs |
|------|---------|-----|
| render.sh | Screen rendering | FR-040, FR-041 |
| widgets.sh | Progress bars, counters | FR-042, FR-044, FR-045 |
| tail.sh | Log tail display | FR-047 |
| input.sh | Keyboard handling | FR-049 |

**FRs Addressed:** FR-040 - FR-049

---

### Component: Feedback System (lib/feedback/)

**Purpose:** Mandatory feedback collection and storage

| File | Purpose | FRs |
|------|---------|-----|
| questionnaire.sh | Interactive questionnaire | FR-051 |
| storage.sh | Feedback file management | FR-052 |
| report.sh | Feedback analytics | FR-057 |

**FRs Addressed:** FR-051 - FR-057

---

### Component: Generator (lib/generator/)

**Purpose:** Loop file generation

| File | Purpose | FRs |
|------|---------|-----|
| loop_sh.sh | Generate loop.sh | FR-012 |
| prd_json.sh | Generate prd.json | FR-013 |
| prompt_md.sh | Generate prompt.md | FR-014 |
| progress_txt.sh | Generate progress.txt | FR-015 |

**FRs Addressed:** FR-012 - FR-015

---

## Data Architecture

### Data Model

Ralph uses **file-based storage** with structured YAML and JSON files.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Data Entities                               │
├─────────────────────────────────────────────────────────────────────┤
│  Global Config (1:1 per project)                                    │
│  └── ralph/config.yaml                                              │
│                                                                      │
│  Loop (1:N per project)                                             │
│  └── ralph/loops/<loop-name>/                                       │
│      ├── prd.json         (config + execution metadata)             │
│      ├── loop.sh          (orchestration script)                    │
│      ├── prompt.md        (Claude context)                          │
│      └── progress.txt     (iteration log)                           │
│                                                                      │
│  Archived Loop (1:N per project)                                    │
│  └── ralph/archive/<date>-<loop-name>/                              │
│      └── (same files + feedback.json)                               │
│                                                                      │
│  Sprint Status (BMAD-owned, read/write)                             │
│  └── docs/sprint-status.yaml                                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Database Design

**config.yaml Schema:**
```yaml
version: "1.0"
project_name: "my-project"
initialized_at: "2026-01-10T20:00:00Z"

bmad:
  sprint_status_path: "docs/sprint-status.yaml"
  config_path: "bmad/config.yaml"

defaults:
  max_iterations: 50
  stuck_threshold: 3
  quality_gates:
    typecheck: true
    test: true
    lint: false
    build: true

commands:
  typecheck: "npm run typecheck"
  test: "npm test"
  lint: "npm run lint"
  build: "npm run build"
```

**prd.json Schema:**
```json
{
  "version": "1.0",
  "loopName": "feature-auth",
  "createdAt": "2026-01-10T20:00:00Z",
  "branchName": "ralph/feature-auth",

  "scope": {
    "epicFilter": "EPIC-001",
    "storyIds": ["STORY-001", "STORY-002"]
  },

  "config": {
    "maxIterations": 50,
    "stuckThreshold": 3,
    "qualityGates": {
      "typecheck": true,
      "test": true,
      "build": true
    }
  },

  "stats": {
    "startedAt": null,
    "completedAt": null,
    "iterationsRun": 0,
    "storiesCompleted": 0
  },

  "storyNotes": {},
  "status": "active"
}
```

**feedback.json Schema:**
```json
{
  "version": "1.0",
  "loopName": "feature-auth",
  "archivedAt": "2026-01-11T15:00:00Z",

  "questionnaire": {
    "satisfaction": 4,
    "manualInterventions": 1,
    "whatWorkedWell": "Quality gates caught issues early",
    "whatToImprove": "Better stuck detection",
    "runAgain": true
  },

  "summary": {
    "storiesCompleted": 3,
    "iterationsUsed": 12
  }
}
```

### Data Flow

```
1. CREATE FLOW:
   sprint-status.yaml ──[read]──▶ analyze stories
                                        │
                                        ▼
                               generate loop files
                                        │
                                        ▼
   prd.json ◀──[write]──────────────────┘
   loop.sh  ◀──[write]──────────────────┘
   prompt.md ◀──[write]─────────────────┘

2. RUN FLOW:
   prd.json ──[read]──▶ get current story
                              │
                              ▼
   prompt.md ──[read]──▶ claude CLI ──▶ code changes
                                              │
                                              ▼
   sprint-status.yaml ◀──[write]──── update story status
   prd.json ◀──[write]────────────── update stats
   progress.txt ◀──[append]───────── log iteration

3. ARCHIVE FLOW:
   loops/<name>/ ──[move]──▶ archive/<date>-<name>/
   feedback ──[collect]──▶ feedback.json
```

---

## CLI Interface Design

### Interface Architecture

**Pattern:** Git-style subcommand routing
```
ralph <command> [arguments] [flags]
```

**Global Flags:**
| Flag | Description |
|------|-------------|
| `--help`, `-h` | Show help |
| `--version`, `-v` | Show version |
| `--verbose` | Enable verbose output |
| `--quiet`, `-q` | Suppress non-error output |
| `--no-color` | Disable colored output |

### Command Reference

| Command | Description | Key Flags |
|---------|-------------|-----------|
| `ralph init` | Initialize ralph | `--force` |
| `ralph create <name>` | Create new loop | `--epic`, `--yes`, `--no-branch` |
| `ralph list` | List all loops | `--active`, `--archived`, `--json` |
| `ralph show <name>` | Show loop details | `--json` |
| `ralph run <name>` | Execute loop | `--dry-run`, `--restart` |
| `ralph status <name>` | Monitoring dashboard | `--refresh`, `--once` |
| `ralph archive <name>` | Archive with feedback | (feedback required) |
| `ralph delete <name>` | Delete loop | `--force` |

### Error Message Format

```
ERROR: <What went wrong>
<Why it went wrong>

To fix:
  - <Recovery option 1>
  - <Recovery option 2>
```

---

## Non-Functional Requirements Coverage

### NFR-001: CLI Response Time

**Requirement:** Non-execution commands < 2s, help/version < 0.5s

**Solution:**
- Lazy loading: Only source modules needed for specific command
- No external tool calls for help/version (pure bash)
- Cache dependency checks in session

**Validation:** `time ralph --help` < 0.5s

---

### NFR-010: State Persistence

**Requirement:** State survives crashes, no data loss

**Solution:**
- Atomic file writes (temp + rename pattern)
- Write state after every significant action
- Lock files prevent concurrent corruption

**Implementation:**
```bash
atomic_write() {
    local file="$1" content="$2"
    local tmp="${file}.tmp.$$"
    echo "$content" > "$tmp" && mv "$tmp" "$file"
}
```

---

### NFR-011: Atomic File Updates

**Requirement:** No partial writes

**Solution:**
- All writes go through atomic_write function
- Use jq/yq to modify in memory, then atomic write
- Never write directly to target file

---

### NFR-021: Colored Terminal Output

**Requirement:** Color-coded output

**Solution:**
- ANSI escape sequences for colors
- Respect NO_COLOR environment variable
- tput for terminal-safe colors

**Implementation:**
```bash
setup_colors() {
    if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        RED='' GREEN='' YELLOW='' BLUE='' NC=''
    else
        RED='\033[0;31m' GREEN='\033[0;32m' # etc
    fi
}
```

---

### NFR-030/031: macOS and Linux Support

**Requirement:** Works on macOS 12+ and Linux (Ubuntu 20.04+)

**Solution:**
- POSIX-compliant bash subset
- Use GNU-compatible options
- No OS-specific commands
- Test on both platforms in CI

---

### NFR-034: Claude CLI Compatibility

**Requirement:** Works with Claude Code CLI v1.x

**Solution:**
- Wrap Claude calls in abstraction layer
- Use stable flags only (--print, -p)
- Document minimum version

**Implementation:**
```bash
claude_run() {
    local prompt="$1"
    claude --print --dangerously-skip-permissions -p "$prompt"
}
```

---

## Security Architecture

### Threat Model

| Threat | Risk | Mitigation |
|--------|------|------------|
| Command injection | High | Input validation, quoting |
| Sensitive data exposure | Medium | No secrets in logs |
| Path traversal | Low | Validate loop names |

### Input Validation

```bash
validate_loop_name() {
    local name="$1"
    # Only alphanumeric and hyphens
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; then
        error "Invalid loop name"
    fi
    # Prevent path traversal
    if [[ "$name" == *".."* ]] || [[ "$name" == *"/"* ]]; then
        error "Path components not allowed"
    fi
}
```

### Safe Command Execution

- All variable expansions double-quoted (enforced by ShellCheck)
- Never use eval with user input
- Use arrays for dynamic commands

---

## Scalability & Performance

### Performance Optimizations

| Optimization | Benefit |
|--------------|---------|
| Lazy module loading | Fast startup for simple commands |
| YAML/JSON caching | Avoid re-parsing large files |
| Append-only logging | O(1) writes regardless of log size |
| Stream processing | Handle 100MB+ files |

### Capacity Limits

| Resource | Soft Limit | Hard Limit |
|----------|------------|------------|
| Active loops | 10 | 100 |
| Stories per loop | 50 | 200 |
| Progress.txt size | 10MB | 100MB |

---

## Reliability & Availability

### Crash Recovery

- Atomic file writes ensure no partial state
- Lock files detect stale processes
- Resume from prd.json state on next run

### Signal Handling

```bash
setup_signal_handlers() {
    trap 'handle_interrupt' INT TERM
    trap 'handle_exit' EXIT
}

handle_interrupt() {
    warn "Interrupt received, saving state..."
    save_current_state
    cleanup_lock
    exit 130
}
```

### Stale Lock Detection

- Check if PID in lock file still exists
- Timeout locks older than 24 hours

---

## Development Architecture

### Code Organization

```
ralph/
├── bin/ralph              # Entry point
├── lib/
│   ├── commands/          # Command implementations
│   ├── core/              # Shared utilities
│   ├── engine/            # Loop execution
│   ├── dashboard/         # Terminal UI
│   ├── feedback/          # Feedback system
│   ├── generator/         # File generation
│   └── tools/             # External tool wrappers
├── templates/             # Loop file templates
├── tests/                 # Bats tests
├── Makefile               # Build orchestration
└── install.sh             # Installation script
```

### Testing Strategy

| Type | Framework | Coverage Target |
|------|-----------|-----------------|
| Unit | Bats | 90% (core), 80% (commands) |
| Integration | Bats | Full loop lifecycle |
| Linting | ShellCheck | 100% pass |

### CI/CD Pipeline

```yaml
jobs:
  lint:
    - ShellCheck on all .sh files
  test:
    matrix: [ubuntu-latest, macos-latest]
    - Install dependencies
    - Run bats tests
  release:
    - Tag-triggered
    - Create GitHub release
```

---

## Requirements Traceability

### Functional Requirements Coverage

| Epic | FRs | Components |
|------|-----|------------|
| EPIC-001: CLI Foundation | FR-001, FR-002, FR-003 | bin/ralph, lib/commands/init.sh |
| EPIC-002: Loop Creation | FR-010 - FR-019 | lib/commands/create.sh, lib/generator/ |
| EPIC-003: Loop Management | FR-020 - FR-025 | lib/commands/{list,show,delete,edit}.sh |
| EPIC-004: Loop Execution | FR-030 - FR-039 | lib/commands/run.sh, lib/engine/ |
| EPIC-005: Monitoring | FR-040 - FR-049 | lib/commands/status.sh, lib/dashboard/ |
| EPIC-006: Archive & Feedback | FR-050 - FR-058 | lib/commands/archive.sh, lib/feedback/ |
| EPIC-007: BMAD Integration | FR-060 - FR-065 | lib/core/config.sh, external BMAD files |

### Non-Functional Requirements Coverage

| Category | NFRs | Primary Solution |
|----------|------|------------------|
| Performance | NFR-001, NFR-002, NFR-003 | Lazy loading, caching, streaming |
| Reliability | NFR-010 - NFR-014 | Atomic writes, locks, validation |
| Usability | NFR-020 - NFR-025 | Consistent CLI, colors, confirmations |
| Compatibility | NFR-030 - NFR-034 | POSIX bash, abstraction layers |
| Maintainability | NFR-040 - NFR-043 | Modular structure, tests, docs |

---

## Trade-offs & Decision Log

### Decision 1: Bash vs. Compiled Language

- ✓ **Gain:** No build step, universal availability, readable source
- ✗ **Lose:** Performance ceiling, limited data structures
- **Rationale:** PRD mandates bash-only

### Decision 2: File-Based Storage vs. SQLite

- ✓ **Gain:** Human-readable, easy debugging, no deps
- ✗ **Lose:** No transactions, manual atomicity
- **Rationale:** Aligns with BMAD's YAML/JSON patterns

### Decision 3: External Tools (jq, yq) vs. Pure Bash

- ✓ **Gain:** Powerful JSON/YAML processing, standard tools
- ✗ **Lose:** External dependencies
- **Rationale:** Pure bash parsing is fragile and unmaintainable

### Decision 4: Rich Dashboard vs. Simple Output

- ✓ **Gain:** Better UX, real-time visibility
- ✗ **Lose:** Terminal compatibility concerns
- **Rationale:** Key differentiator, fallbacks mitigate issues

### Decision 5: Mandatory Feedback vs. Optional

- ✓ **Gain:** Guaranteed data collection, drives improvement
- ✗ **Lose:** User friction
- **Rationale:** PRD requirement, core to improvement cycle

---

## Open Issues & Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Claude CLI API changes | Medium | High | Abstraction layer, version pinning |
| Loops get stuck frequently | Medium | Medium | Configurable threshold, clear errors |
| Poor quality output | Medium | High | Quality gates, good prompts |

---

## Assumptions & Constraints

### Assumptions

1. Users have Claude Code CLI installed and authenticated
2. Users have BMAD-initialized project with sprint-status.yaml
3. Users have jq/yq installed (or willing to install)
4. Git configured with appropriate permissions
5. One loop runs at a time per project

### Constraints

1. Bash-only implementation (no compiled languages)
2. macOS/Linux only (no Windows support)
3. Must use Claude Code CLI as execution engine
4. Must follow BMAD method protocols
5. CLI-only interface (no GUI for v1)

---

## Future Considerations

1. **Web Dashboard:** Team visibility for shared projects
2. **CI/CD Integration:** Automated loop triggering
3. **Auto PR Creation:** Create PRs from completed loops
4. **Parallel Execution:** Run multiple loops simultaneously
5. **Multi-Model Support:** Integration with other AI models
6. **Log Rotation:** Automatic rotation for large progress files

---

## Approval & Sign-off

**Review Status:**
- [ ] Technical Lead
- [ ] Product Owner
- [ ] DevOps Lead

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-10 | Jean-Philippe Brule | Initial architecture |

---

## Next Steps

### Phase 4: Sprint Planning & Implementation

Run `/sprint-planning` to:
- Break epics into detailed user stories
- Estimate story complexity
- Plan sprint iterations
- Begin implementation following this architectural blueprint

**Key Implementation Principles:**
1. Follow component boundaries defined in this document
2. Implement NFR solutions as specified
3. Use technology stack as defined
4. Follow CLI contracts exactly
5. Adhere to security and performance guidelines

---

**This document was created using BMAD Method v6 - Phase 3 (Solutioning)**

*To continue: Run `/workflow-status` to see your progress and next recommended workflow.*

---

## Appendix A: Full FR Traceability Matrix

| FR ID | FR Name | Component(s) |
|-------|---------|--------------|
| FR-001 | Initialize Ralph | lib/commands/init.sh |
| FR-002 | Help Command | bin/ralph |
| FR-003 | Version Command | bin/ralph |
| FR-010 | Create Loop | lib/commands/create.sh |
| FR-011 | Sprint Analysis | lib/tools/yaml.sh |
| FR-012 | Generate loop.sh | lib/generator/loop_sh.sh |
| FR-013 | Generate prd.json | lib/generator/prd_json.sh |
| FR-014 | Generate prompt.md | lib/generator/prompt_md.sh |
| FR-015 | Generate progress.txt | lib/generator/progress_txt.sh |
| FR-016 | Git Branch | lib/tools/git.sh |
| FR-017 | Interactive Config | lib/core/prompts.sh |
| FR-018 | Quality Gates Config | lib/engine/gates.sh |
| FR-019 | Template Customization | lib/generator/ |
| FR-020 | List Loops | lib/commands/list.sh |
| FR-021 | Delete Loop | lib/commands/delete.sh |
| FR-022 | Show Loop Details | lib/commands/show.sh |
| FR-023 | Edit Loop | lib/commands/edit.sh |
| FR-024 | Clone Loop | lib/commands/clone.sh |
| FR-025 | Resume Loop | lib/core/state.sh |
| FR-030 | Run Loop | lib/commands/run.sh |
| FR-031 | Claude Integration | lib/tools/claude.sh |
| FR-032 | Completion Detection | lib/engine/detector.sh |
| FR-033 | Stuck Detection | lib/engine/detector.sh |
| FR-034 | Quality Gates | lib/engine/gates.sh |
| FR-035 | Iteration Logging | lib/core/state.sh |
| FR-036 | Graceful Interrupt | lib/commands/run.sh |
| FR-037 | Statistics | lib/engine/stats.sh |
| FR-038 | Concurrent Prevention | lib/core/state.sh |
| FR-039 | Dry Run | lib/commands/run.sh |
| FR-040 | Status Dashboard | lib/dashboard/render.sh |
| FR-041 | Progress Visualization | lib/dashboard/widgets.sh |
| FR-042 | Current Story Display | lib/dashboard/render.sh |
| FR-043 | ETA Calculation | lib/dashboard/widgets.sh |
| FR-044 | Iteration Counter | lib/dashboard/widgets.sh |
| FR-045 | Stuck Warning | lib/dashboard/widgets.sh |
| FR-046 | Gate Status | lib/dashboard/widgets.sh |
| FR-047 | Log Tail | lib/dashboard/tail.sh |
| FR-048 | Refresh Rate | lib/dashboard/render.sh |
| FR-049 | Keyboard Controls | lib/dashboard/input.sh |
| FR-050 | Archive Loop | lib/commands/archive.sh |
| FR-051 | Feedback Questionnaire | lib/feedback/questionnaire.sh |
| FR-052 | Feedback Storage | lib/feedback/storage.sh |
| FR-053 | Archive Structure | lib/commands/archive.sh |
| FR-054 | List Archived | lib/commands/list.sh |
| FR-055 | Show Archived | lib/commands/show.sh |
| FR-056 | Unarchive | lib/commands/unarchive.sh |
| FR-057 | Feedback Analytics | lib/feedback/report.sh |
| FR-058 | Auto-Archive Prompt | lib/commands/run.sh |
| FR-060 | Agent Definition | BMAD agent file |
| FR-061 | Workflow Registration | BMAD workflow |
| FR-062 | SKILL.md Integration | SKILL.md |
| FR-063 | Auto-Install | lib/commands/init.sh |
| FR-064 | Sprint Status Integration | lib/tools/yaml.sh |
| FR-065 | BMAD Config Detection | lib/core/config.sh |

---

## Appendix B: Full NFR Traceability Matrix

| NFR ID | NFR Name | Solution |
|--------|----------|----------|
| NFR-001 | CLI Response Time | Lazy loading |
| NFR-002 | Dashboard Refresh | tput, sleep |
| NFR-003 | File I/O Efficiency | Append-only, streaming |
| NFR-010 | State Persistence | Atomic writes |
| NFR-011 | Atomic Updates | temp + rename |
| NFR-012 | Error Recovery | Error template |
| NFR-013 | Dependency Validation | check_deps |
| NFR-014 | Idempotent Operations | State checks |
| NFR-020 | Intuitive Commands | Git-style |
| NFR-021 | Colored Output | ANSI + NO_COLOR |
| NFR-022 | Clear Errors | What/why/fix |
| NFR-023 | Progress Feedback | Spinners |
| NFR-024 | Confirmations | Default no |
| NFR-025 | Helpful Defaults | Embedded defaults |
| NFR-030 | macOS Support | POSIX bash |
| NFR-031 | Linux Support | POSIX bash |
| NFR-032 | Terminal Compat | tput fallbacks |
| NFR-033 | BMAD Compat | Follow schema |
| NFR-034 | Claude Compat | Stable flags |
| NFR-040 | Code Organization | Modules |
| NFR-041 | Documentation | Function headers |
| NFR-042 | Testing | Bats |
| NFR-043 | Debug Logging | RALPH_DEBUG |
