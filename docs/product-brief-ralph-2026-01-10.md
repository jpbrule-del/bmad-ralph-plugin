# Product Brief: ralph

**Date:** 2026-01-10
**Author:** Jean-Philippe Brule
**Version:** 1.0
**Project Type:** cli-tool
**Project Level:** 3 (Complex, 12-40 stories)

---

## Executive Summary

Ralph is a BMAD Phase 4 autonomous execution workflow and CLI tool that automates story implementation after sprint planning. It reads sprint-status.yaml, creates custom automation loops, and executes stories autonomously using Claude Code CLI. The CLI enables developers to create, manage, and run different ralph loops within a project, transforming backlogs into ready-to-review PRs without manual coding.

---

## Problem Statement

### The Problem

Developers spend significant time on manual coding when they'd rather be reviewing PRs and focusing on higher-level work. After sprint planning in BMAD, there's no automated way to execute through a backlog of stories - each story requires manual implementation, creating bottlenecks and slowing delivery.

### Why Now?

Claude Opus 4.5 is a game-changer. AI agent capability is finally mature enough to autonomously implement stories with high quality when combined with the BMAD method's structured approach. The combination of structured sprint planning (BMAD) + powerful AI execution (Claude) + automation orchestration (ralph) creates a viable autonomous development pipeline.

### Impact if Unsolved

Precious time lost on manual implementation. Customers lost to competitors due to slow delivery from growing backlogs. Developer frustration from repetitive coding tasks that AI can handle.

---

## Target Audience

### Primary Users

Solo developers using BMAD who work exclusively in Claude Code CLI. These are highly technical users who:
- Prefer CLI-first workflows
- Already use BMAD method for project planning
- Have Claude Code CLI installed and configured
- Want to maximize automation and minimize manual coding
- Value efficiency and are comfortable with autonomous AI execution

### Secondary Users

None - ralph is a personal developer tool installed on individual machines.

### User Needs

1. Automated story execution after sprint planning
2. Real-time visibility into loop progress
3. Easy management of multiple loops per project
4. Feedback mechanism to improve the tool over time

---

## Solution Overview

### Proposed Solution

A bash CLI tool that integrates with BMAD method to automate Phase 4 (Implementation). Ralph analyzes sprint-status.yaml, generates custom loop configurations, and orchestrates Claude Code CLI to execute stories autonomously.

### Key Features

- **CLI Commands:** Full CRUD operations on loops plus execution and monitoring
  - `ralph init` - Initialize ralph in a BMAD project
  - `ralph create <loop-name>` - Analyze sprint-status, create loop files, create git branch
  - `ralph list` - List all loops (active + archived)
  - `ralph run <loop-name>` - Execute a loop
  - `ralph status <loop-name>` - Live monitoring dashboard
  - `ralph archive <loop-name>` - Archive with mandatory feedback
  - `ralph delete <loop-name>` - Remove a loop

- **Loop File Generation:** Auto-generates all files needed for autonomous execution
  - `loop.sh` - Orchestration script
  - `prd.json` - Configuration + execution metadata
  - `prompt.md` - Context for Claude
  - `progress.txt` - Iteration log

- **Real-Time Monitoring Dashboard:** Rich terminal UI with:
  - Progress bars and color-coded output
  - Current story being worked on
  - ETA for completion
  - Iteration count and stuck detection
  - Quality gate results

- **Mandatory Feedback System:** Required questionnaire before archiving loops to drive continuous improvement

- **BMAD Compliance:** Reads sprint-status.yaml, follows commit policies, integrates with existing BMAD workflows

### Value Proposition

Developers review PRs instead of writing code. Ralph transforms a planned sprint into implemented, committed code ready for review - reducing manual coding time by 80% and clearing backlogs 3x faster.

---

## Business Objectives

### Goals

- Reduce manual coding time by 80% for routine story implementation
- Clear backlogs 3x faster through automated execution
- Standardize autonomous execution across the team via shared monorepo
- Collect user feedback to continuously improve ralph

### Success Metrics

- User feedback scores collected via mandatory questionnaire
- Average feedback score > 4/5
- Percentage of loops completing without manual intervention (target: 70%+)
- Team adoption rate (target: 100% of team using ralph)

### Business Value

- Faster time-to-market for features
- Reduced developer fatigue on repetitive tasks
- Consistent implementation quality through structured automation
- Competitive advantage through AI-augmented development velocity

---

## Scope

### In Scope

- CLI commands: init, create, list, run, status, archive, delete
- Loop file generation (loop.sh, prd.json, prompt.md, progress.txt)
- Auto git branch creation on `ralph create`
- Real-time monitoring dashboard with `ralph status`
- Mandatory feedback questionnaire before archive
- BMAD method compliance (reads sprint-status.yaml, follows commit policies)
- Archive system with date-based naming
- Storage structure: `ralph/loops/<loop-name>/`
- macOS and Linux support
- Bash implementation with jq/yq dependencies

### Out of Scope

- GUI/web interface
- Multi-machine distributed execution
- CI/CD pipeline integration
- Auto PR creation (commits only for v1)
- Windows support

### Future Considerations

- Web dashboard for team visibility
- CI/CD integration for automated loop triggering
- Auto PR creation with review assignments
- Parallel loop execution
- Integration with other AI models beyond Claude

---

## Key Stakeholders

- **Project Lead** - High influence. Defines requirements, approves design, drives adoption.
- **Team Developers** - High influence. Primary users, contributors to shared monorepo.

---

## Constraints and Assumptions

### Constraints

- Bash-only implementation (no compiled languages)
- macOS/Linux only (no Windows support)
- Must use Claude Code CLI as execution engine
- Must follow BMAD method protocols exactly
- CLI-only interface (no GUI for v1)
- Dependencies: jq, yq, git, claude CLI

### Assumptions

- Users have Claude Code CLI installed and authenticated
- Users have BMAD-initialized project with sprint-status.yaml
- Users have jq/yq installed (or willing to install)
- Git configured with appropriate permissions
- One loop runs at a time per project
- Users are comfortable with autonomous AI execution

---

## Success Criteria

- Team adopts ralph for all sprint execution
- Average feedback score > 4/5
- Loops complete without manual intervention 70%+ of the time
- Backlog velocity measurably increases
- All team members successfully install and use ralph
- Zero critical bugs in production use

---

## Timeline and Milestones

### Key Milestones

| Milestone | Description |
|-----------|-------------|
| M1 | Core CLI structure (init, create, list, delete) |
| M2 | Loop execution (run command working) |
| M3 | Monitoring dashboard (status command) |
| M4 | Feedback system + archive flow |
| M5 | Documentation + team rollout |

---

## Risks and Mitigation

- **Risk:** Claude CLI API changes break ralph
  - **Likelihood:** Medium
  - **Impact:** High
  - **Mitigation:** Pin to stable CLI version, monitor releases, abstract CLI calls

- **Risk:** Loops get stuck frequently
  - **Likelihood:** Medium
  - **Impact:** Medium
  - **Mitigation:** Stuck detection with configurable threshold, manual intervention hooks, clear error reporting

- **Risk:** Poor quality output requiring heavy review
  - **Likelihood:** Medium
  - **Impact:** High
  - **Mitigation:** Quality gates (analyze, test, build), consensus validation step, good prompt engineering

- **Risk:** Team adoption resistance
  - **Likelihood:** Low
  - **Impact:** Medium
  - **Mitigation:** Good documentation, demo sessions, mandatory feedback loop for continuous improvement

---

## Technical Context

### Directory Structure

```
project/
├── ralph/
│   ├── config.yaml           # Ralph global config
│   └── loops/
│       ├── feature-auth/
│       │   ├── loop.sh
│       │   ├── prd.json
│       │   ├── prompt.md
│       │   └── progress.txt
│       └── bugfix-api/
│           └── ...
├── docs/
│   └── sprint-status.yaml    # BMAD sprint status (read-only)
└── bmad/
    └── config.yaml           # BMAD config
```

### Integration Points

- **BMAD sprint-status.yaml:** Source of truth for stories (read-only)
- **Claude Code CLI:** Execution engine (`claude` command)
- **Git:** Branch creation, commits following BMAD policies
- **Quality Gates:** Project-specific commands (flutter analyze, npm test, etc.)

### Feedback Questionnaire Fields

1. Overall satisfaction (1-5 scale)
2. Stories requiring manual intervention (count)
3. What worked well? (free text)
4. What should be improved? (free text)
5. Would you run this configuration again? (yes/no)

---

## Next Steps

1. Create Product Requirements Document (PRD) - `/prd`
2. Design system architecture - `/architecture`
3. Sprint planning - `/sprint-planning`

---

**This document was created using BMAD Method v6 - Phase 1 (Analysis)**

*To continue: Run `/workflow-status` to see your progress and next recommended workflow.*
