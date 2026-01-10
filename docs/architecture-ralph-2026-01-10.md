# System Architecture: Ralph

**Date:** 2026-01-10
**Architect:** jean-philippebrule
**Version:** 1.0
**Project Type:** library (BMAD workflow)
**Project Level:** 3
**Status:** Draft

---

## Document Overview

This document defines the system architecture for Ralph - the autonomous execution workflow for BMAD Method (Phase 5). It provides the technical blueprint for implementation, addressing all functional and non-functional requirements from the PRD.

**Related Documents:**
- Product Requirements Document: `docs/prd-ralph-2026-01-10.md`
- Product Brief: `docs/product-brief-ralph-2026-01-10.md`

---

## Executive Summary

Ralph is a BMAD workflow that enables autonomous code implementation using Claude Code. After completing product brief, PRD, architecture, and sprint planning (Phases 1-4), developers run `/ralph` to automatically implement all stories.

The architecture follows a **Pipeline Pattern with State Machine** design:
1. **Ingestion Layer** - Reads all BMAD documentation
2. **Interview Layer** - Gathers loop configuration from user
3. **Generation Layer** - Creates prd.json, prompt.md, loop.sh
4. **Execution Engine** - Runs autonomous loop until complete

All state is persisted in files (no database), enabling resumability and human inspection.

---

## Architectural Drivers

These NFRs most heavily influence design decisions:

| NFR | Requirement | Architectural Impact |
|-----|-------------|---------------------|
| NFR-001 | Error Handling | Atomic file writes, graceful degradation, signal traps |
| NFR-002 | Stuck Detection | Attempt tracking per story, configurable threshold |
| NFR-004 | Resumability | All state in files, idempotent operations |
| NFR-005 | Claude CLI Compat | Must use exact CLI flags and parse output |
| NFR-006 | Shell Compat | Portable bash, common tools only |
| NFR-007 | BMAD Patterns | Standard workflow structure, helper usage |

**Primary Design Principles:**
1. **Reliability through simplicity** - Bash + files, no complex dependencies
2. **State persistence** - All state in human-readable files
3. **BMAD integration** - Native workflow that fits the ecosystem

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           /ralph WORKFLOW                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐               │
│  │   INGESTION  │───▶│  INTERVIEW   │───▶│  GENERATION  │               │
│  │    LAYER     │    │    LAYER     │    │    LAYER     │               │
│  └──────────────┘    └──────────────┘    └──────────────┘               │
│         │                   │                   │                        │
│         ▼                   ▼                   ▼                        │
│  ┌─────────────────────────────────────────────────────┐                │
│  │                   STATE FILES                        │                │
│  │  docs/*.md  │  ralph/prd.json  │  ralph/progress.txt │                │
│  └─────────────────────────────────────────────────────┘                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXECUTION ENGINE                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                        loop.sh                                   │    │
│  │  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐         │    │
│  │  │  PICK   │──▶│  INVOKE │──▶│  VERIFY │──▶│ UPDATE  │──┐      │    │
│  │  │  STORY  │   │  CLAUDE │   │  GATES  │   │  STATE  │  │      │    │
│  │  └─────────┘   └─────────┘   └─────────┘   └─────────┘  │      │    │
│  │       ▲                                                  │      │    │
│  │       └──────────────────────────────────────────────────┘      │    │
│  │                         (loop until done/stuck/max)              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                   │                                      │
│                                   ▼                                      │
│                          ┌──────────────┐                               │
│                          │ Claude CLI   │                               │
│                          │ --print      │                               │
│                          │ --dangerously│                               │
│                          └──────────────┘                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Architectural Pattern

**Pattern:** Pipeline Architecture with State Machine

**Rationale:**
- Pipeline pattern suits sequential processing (ingest → interview → generate → execute)
- State machine handles loop control (pick → invoke → verify → update → repeat)
- File-based state enables resumability without databases
- Separation allows testing each layer independently

---

## Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Workflow Definition** | Markdown (BMAD workflow.md) | Consistent with BMAD patterns, Claude Code native |
| **Script Runtime** | Bash | Universal, no dependencies, portable |
| **JSON Processing** | jq | Standard CLI tool, powerful queries |
| **Version Control** | Git | Required for commits, already present |
| **AI Runtime** | Claude CLI | `claude --print --dangerously-skip-permissions` |
| **File Format (State)** | JSON (prd.json) | Structured, jq-parseable |
| **File Format (Context)** | Markdown | Human-readable, Claude-friendly |

**No additional dependencies required** - uses tools developers already have.

---

## System Components

### Component 1: Workflow Orchestrator

**File:** `~/.claude/config/bmad/modules/bmm/workflows/ralph.md`

**Purpose:** BMAD workflow file that Claude Code loads when user runs `/ralph`

**Responsibilities:**
- Define workflow steps and interview questions
- Orchestrate document ingestion
- Guide user through configuration
- Trigger file generation
- Launch execution engine

**Interfaces:**
- Input: User invokes `/ralph` in Claude Code
- Output: Generated files in `ralph/` directory

**FRs Addressed:** FR-001, FR-002, FR-006

---

### Component 2: Document Ingester

**Purpose:** Read and parse all BMAD documentation

**Responsibilities:**
- Locate BMAD files using glob patterns
- Parse markdown documents (extract sections)
- Parse YAML files (sprint-status.yaml)
- Build unified project context

**File Patterns:**
```
docs/product-brief-*.md
docs/prd-*.md
docs/architecture-*.md
docs/sprint-status.yaml
docs/stories/**/*.md
```

**FRs Addressed:** FR-001

---

### Component 3: Configuration Interviewer

**Purpose:** Gather loop configuration from user

**Responsibilities:**
- Display found documentation summary
- Ask scope questions (which stories)
- Ask quality gate questions (commands)
- Ask loop parameter questions (limits)
- Collect custom instructions

**Interview Steps:**
1. Document Summary
2. Scope Selection (all/epic/stories)
3. Quality Gates (typecheck, test, lint, build)
4. Loop Parameters (max iterations, stuck threshold)
5. Custom Instructions (optional)

**FRs Addressed:** FR-002

---

### Component 4: File Generator

**Purpose:** Generate all loop execution files

**Outputs:**
| File | Purpose |
|------|---------|
| `ralph/prd.json` | Loop state and story tracking |
| `ralph/prompt.md` | Context for each Claude iteration |
| `ralph/loop.sh` | Bash execution script |
| `ralph/progress.txt` | Append-only iteration log |

**FRs Addressed:** FR-003, FR-004, FR-005, FR-009

---

### Component 5: Execution Engine

**File:** `ralph/loop.sh`

**Purpose:** Run autonomous loop until completion

**State Machine:**
```
PICK_STORY → INVOKE_CLAUDE → VERIFY_GATES → UPDATE_STATE → (repeat)
                                    │
                                    ├── PASS → commit, next story
                                    └── FAIL → increment attempts, check stuck
```

**Exit Conditions:**
| Condition | Exit Code | Message |
|-----------|-----------|---------|
| All stories pass | 0 | COMPLETE |
| Story stuck (N failures) | 1 | STUCK |
| Max iterations reached | 2 | MAX_ITERATIONS |
| User interrupt (Ctrl+C) | 130 | INTERRUPTED |

**FRs Addressed:** FR-006, FR-007

---

### Component 6: State Manager

**Purpose:** Manage persistent state across runs

**Responsibilities:**
- Atomic file updates (temp + mv)
- Archive previous runs
- Track iteration history
- Enable resume capability

**Archive Structure:**
```
ralph/archive/
└── 2026-01-10-feature-name/
    ├── prd.json
    ├── prompt.md
    └── progress.txt
```

**FRs Addressed:** FR-008, FR-009

---

## Data Architecture

### prd.json Schema

```json
{
  "project": "string",
  "branchName": "string (ralph/feature-name)",
  "description": "string",
  "generatedAt": "ISO timestamp",
  "config": {
    "maxIterations": 50,
    "stuckThreshold": 3,
    "qualityGates": {
      "typecheck": "string | null",
      "test": "string | null",
      "lint": "string | null",
      "build": "string | null"
    }
  },
  "stats": {
    "iterationsRun": 0,
    "storiesCompleted": 0,
    "startedAt": "ISO timestamp | null",
    "completedAt": "ISO timestamp | null"
  },
  "userStories": [
    {
      "id": "US-001",
      "epicId": "EPIC-001",
      "title": "string",
      "description": "string",
      "acceptanceCriteria": ["string"],
      "priority": 1,
      "passes": false,
      "attempts": 0,
      "notes": "",
      "completedAt": null
    }
  ]
}
```

### progress.txt Format

```markdown
# Ralph Progress Log
# Project: {project_name}
# Feature: {branch_name}
# Started: {timestamp}

---

## Iteration 1 - US-001: Story Title
**Status:** PASSED | FAILED
**Completed:** {timestamp}
**Learning:** {discovered pattern or gotcha}
**Note for next:** {1-line context for next iteration}

---
```

### prompt.md Structure

```markdown
# Ralph Loop Context

## Project Overview
{From product brief - 3-5 sentences}

## Architecture Patterns
{From architecture - tech stack, patterns, file structure}

## Quality Gates
{Commands that must pass}

## Current Sprint
{Epic and story context}

## Your Task
{Step-by-step instructions}

## Rules
{Execution rules and signals}

## Progress Context
{Last 3 entries from progress.txt}
```

### Data Flow

```
INPUT (Read Only)              GENERATED (Read/Write)         PROJECT (Modified)
─────────────────              ─────────────────────         ─────────────────
docs/product-brief-*.md   ──┐
docs/prd-*.md             ──┼──▶  ralph/prd.json      ──┐
docs/architecture-*.md    ──┤     ralph/prompt.md       ├──▶  src/**/*
docs/sprint-status.yaml   ──┤     ralph/loop.sh         │     AGENTS.md
docs/stories/**/*.md      ──┘     ralph/progress.txt  ──┘     sprint-status.yaml
```

---

## Interface Design

### Claude CLI Invocation

```bash
claude --print --dangerously-skip-permissions -p "$(cat ralph/prompt.md)"
```

| Flag | Purpose |
|------|---------|
| `--print` | Output to stdout (non-interactive) |
| `--dangerously-skip-permissions` | Skip permission prompts |
| `-p` | Pass prompt content directly |

### Output Signals

Claude outputs special signals for loop control:

| Signal | Meaning | Loop Action |
|--------|---------|-------------|
| `<complete>ALL_STORIES_PASSED</complete>` | All done | Exit success |
| `<stuck>STORY_ID: reason</stuck>` | Cannot complete | Increment attempts |

### Quality Gate Interface

```bash
run_quality_gate() {
  local name="$1"
  local cmd="$2"

  [ -z "$cmd" ] && return 0  # Skip if not configured

  echo "[$name] Running: $cmd"
  if eval "$cmd"; then
    echo "[$name] PASSED"
    return 0
  else
    echo "[$name] FAILED"
    return 1
  fi
}
```

### Progress Display

```
╔══════════════════════════════════════════════════════════════════╗
║ Project: Ralph                    Branch: ralph/bmad-workflow     ║
║ Stories: 5/24 complete            Iteration: 8/50                 ║
╚══════════════════════════════════════════════════════════════════╝

=== Iteration 8: US-006 - Add notification dropdown ===
[Claude] Implementing story...
[Claude] Done (38 seconds)
[Typecheck] PASSED
[Tests] PASSED
[Git] Committed: abc1234
[Progress] Updated
```

---

## Non-Functional Requirements Coverage

### NFR-001: Error Handling

**Solution:**
- Atomic file writes (temp + rename)
- Signal traps for Ctrl+C
- Try/catch wrappers for critical operations
- State preserved on any failure

**Validation:** Kill mid-iteration, verify state preserved and resumable

---

### NFR-002: Stuck Detection

**Solution:**
- Track `attempts` per story in prd.json
- Reset to 0 on success
- Exit with STUCK when attempts >= threshold

**Validation:** Fail story 3x, verify clean exit with actionable message

---

### NFR-003: Clear Output

**Solution:**
- Structured output with consistent formatting
- Progress fraction visible at all times
- Clear PASS/FAIL indicators
- Summary on completion

**Validation:** Visual inspection of output readability

---

### NFR-004: Resumability

**Solution:**
- All state in files (prd.json, progress.txt)
- Resume detection on `/ralph` invocation
- Idempotent operations

**Validation:** Stop loop, run `/ralph`, verify continues from next story

---

### NFR-005: Claude CLI Compatibility

**Solution:**
- Exact flag usage documented and tested
- Version check on startup
- Clear error if CLI missing

**Validation:** Test on fresh Claude Code installation

---

### NFR-006: Shell Compatibility

**Solution:**
- Portable bash (avoid bashisms)
- Dependency check on startup
- Works with common tools only

**Validation:** Test on macOS, Linux, WSL

---

### NFR-007: BMAD Patterns

**Solution:**
- Standard workflow file structure
- Uses helpers.md functions
- Integrates with workflow-status.yaml

**Validation:** `/workflow-status` shows Ralph as Phase 5

---

## Security Architecture

### Execution Security

| Consideration | Approach |
|---------------|----------|
| `--dangerously-skip-permissions` | User explicitly opts in; their environment |
| Destructive operations | Quality gates catch broken code before commit |
| Secrets exposure | Don't read .env into prompts; respect .gitignore |

### File Safety

- Only write to `ralph/` directory
- Atomic writes prevent corruption
- Archive previous runs (don't delete)

### Git Safety

- Verify clean working tree before start
- Only commit after quality gates pass
- Branch isolation for changes

---

## Development Architecture

### File Structure

```
~/.claude/config/bmad/
├── modules/
│   └── bmm/
│       └── workflows/
│           └── ralph.md              # Main workflow definition
└── templates/
    └── ralph/
        ├── prompt.template.md        # Prompt template
        ├── loop.template.sh          # Loop script template
        └── progress.template.txt     # Progress header template
```

### Project Output Structure

```
{project}/
├── ralph/
│   ├── prd.json                      # Loop state
│   ├── prompt.md                     # Generated prompt
│   ├── loop.sh                       # Generated script
│   ├── progress.txt                  # Iteration log
│   └── archive/                      # Previous runs
│       └── 2026-01-10-feature/
└── docs/
    └── sprint-status.yaml            # Updated on completion
```

### Testing Strategy

| Test Type | Approach |
|-----------|----------|
| Unit | Test jq queries, bash functions in isolation |
| Integration | Full workflow with mock Claude output |
| E2E | Real loop execution on sample project |

---

## Requirements Traceability

### Functional Requirements

| FR ID | FR Name | Component | Status |
|-------|---------|-----------|--------|
| FR-001 | Document Ingestion | Document Ingester | Designed |
| FR-002 | User Interview | Configuration Interviewer | Designed |
| FR-003 | Story Conversion | File Generator | Designed |
| FR-004 | Prompt Generation | File Generator | Designed |
| FR-005 | Loop Script Generation | File Generator | Designed |
| FR-006 | Loop Execution | Execution Engine | Designed |
| FR-007 | Sprint Status Updates | State Manager | Designed |
| FR-008 | Archive Previous Runs | State Manager | Designed |
| FR-009 | Progress File Init | File Generator | Designed |
| FR-010 | AGENTS.md Integration | Prompt Instructions | Designed |

### Non-Functional Requirements

| NFR ID | NFR Name | Solution | Status |
|--------|----------|----------|--------|
| NFR-001 | Error Handling | Atomic writes, signal traps | Designed |
| NFR-002 | Stuck Detection | Attempt counter, threshold | Designed |
| NFR-003 | Clear Output | Structured formatting | Designed |
| NFR-004 | Resumability | File-based state | Designed |
| NFR-005 | Claude CLI Compat | Exact flags, version check | Designed |
| NFR-006 | Shell Compat | Portable bash | Designed |
| NFR-007 | BMAD Patterns | Standard structure | Designed |

---

## Trade-offs & Decision Log

### Decision 1: Bash over Node.js/Python

- **Choice:** Bash
- **Trade-off:** ✓ Zero dependencies, works everywhere | ✗ Limited error handling
- **Rationale:** Simplicity wins for orchestration tool

### Decision 2: File-based state over SQLite

- **Choice:** JSON/Markdown files
- **Trade-off:** ✓ Human-readable, easy debugging | ✗ Complex queries harder
- **Rationale:** State is simple, files sufficient

### Decision 3: Single-threaded execution

- **Choice:** Sequential story execution
- **Trade-off:** ✓ No conflicts, simple logic | ✗ Cannot parallelize
- **Rationale:** Correctness > speed; parallel is future consideration

### Decision 4: Full context each iteration

- **Choice:** Complete prompt every time
- **Trade-off:** ✓ Consistent context | ✗ Higher token usage
- **Rationale:** Fresh context is Ralph's core pattern

---

## Open Issues & Risks

| Issue | Risk | Mitigation |
|-------|------|------------|
| Claude CLI output parsing | Medium | Test with real CLI, adjust regex |
| Large story exceeds context | High | Document sizing guidelines, stuck detection |
| YAML parsing in bash | Low | Use yq or skip sprint-status sync |

---

## Assumptions & Constraints

### Assumptions

1. Claude CLI `--print` outputs to stdout reliably
2. `jq` is available on target systems
3. Users run Ralph in git repositories
4. Stories are pre-sized to fit one context window
5. Quality gate commands are idempotent

### Constraints

1. Must use Claude Code CLI (subscription required)
2. Bash-only (no Python/Node runtime)
3. Sequential execution (no parallelism)
4. Single machine (no distributed execution)

---

## Future Considerations

| Feature | Priority | Complexity |
|---------|----------|------------|
| Parallel story execution | Future | High |
| Web monitoring dashboard | Future | High |
| Auto story splitting | Future | High |
| BMAD sprint-status sync | v1.1 | Low |
| Custom LLM providers | Future | Medium |

---

## Approval & Sign-off

**Review Status:**
- [x] Technical Lead (self)
- [x] Product Owner (self)
- [ ] Security Architect
- [ ] DevOps Lead

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-10 | jean-philippebrule | Initial architecture |

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
3. Use file schemas exactly as defined
4. Follow interface contracts
5. Adhere to security and error handling guidelines

---

**This document was created using BMAD Method v6 - Phase 3 (Solutioning)**

*To continue: Run `/workflow-status` to see your progress and next recommended workflow.*

---

## Appendix A: Template File Contents

### prompt.template.md

```markdown
# Ralph Loop Context

## Project Overview
{{project_overview}}

## Architecture Patterns
{{architecture_patterns}}

## Quality Gates
Before committing, ALL must pass:
{{quality_gates}}

## Current Sprint
Epic: {{epic_name}}
Stories remaining: {{stories_remaining}}

## Your Task
1. Read prd.json, find highest priority story where passes=false
2. Read progress.txt for context from previous iterations
3. Implement the story following architecture patterns
4. Run quality gates
5. If all pass: commit with message "feat: {{story_title}}"
6. Update prd.json: set passes=true, add notes
7. Append to progress.txt with learning and note for next
8. Update relevant AGENTS.md with discovered patterns

## Rules
- ONE story per iteration
- Small, atomic commits
- ALL quality gates must pass before commit
- If stuck (can't complete), output: <stuck>STORY_ID: reason</stuck>
- If all stories done, output: <complete>ALL_STORIES_PASSED</complete>

## Progress Context
{{progress_context}}
```

### loop.template.sh

```bash
#!/bin/bash
# Ralph Loop - Generated {{timestamp}}
set -e

# Configuration
PROJECT_NAME="{{project}}"
BRANCH_NAME="{{branchName}}"
MAX_ITERATIONS={{maxIterations}}
STUCK_THRESHOLD={{stuckThreshold}}

# Quality Gates
TYPECHECK_CMD="{{typecheck}}"
TEST_CMD="{{test}}"
LINT_CMD="{{lint}}"
BUILD_CMD="{{build}}"

# Paths
PRD_FILE="ralph/prd.json"
PROMPT_FILE="ralph/prompt.md"
PROGRESS_FILE="ralph/progress.txt"

# ... (full implementation)
```

---

## Appendix B: Distribution Package

```
bmad-ralph/
├── README.md
├── install.sh
└── bmad/
    ├── modules/bmm/workflows/ralph.md
    └── templates/ralph/
        ├── prompt.template.md
        ├── loop.template.sh
        └── progress.template.txt
```

**Installation:**
```bash
git clone https://github.com/user/bmad-ralph
cd bmad-ralph && ./install.sh
```
