# Product Brief: Ralph

**Date:** 2026-01-10
**Author:** jean-philippebrule
**Version:** 1.0
**Project Type:** library
**Project Level:** 3

---

## Executive Summary

Ralph is an autonomous AI agent loop template for Claude Code. It enables developers to run Claude Code repeatedly until all PRD items are complete, with memory persisting via git history and status files. This refactored version replaces the Amp-specific implementation with Claude Code compatibility, shifting the developer's focus from real-time supervision to designing quality gates.

---

## Problem Statement

### The Problem

Developers using AI coding assistants spend too much time in a reactive loop - answering questions, correcting mistakes, and supervising in real-time. This limits productivity and keeps the human bottlenecked on AI babysitting rather than higher-value work.

### Why Now?

Claude Code subscriptions are widely available, but there's no standardized autonomous loop pattern for it like Ralph provides for Amp. The original Ralph pattern (by Geoffrey Huntley) proved the concept works - now it needs a Claude Code implementation.

### Impact if Unsolved

Developers remain bottlenecked by real-time supervision, limiting how much AI can accomplish independently. The focus stays on "fixing AI mistakes" rather than "designing quality gates that prevent mistakes."

---

## Target Audience

### Primary Users

Intermediate to senior developers with Claude Code subscriptions who want to maximize autonomous AI productivity. They understand git workflows, testing practices, and are comfortable with CLI tools.

### Secondary Users

Open source contributors who want to extend or adapt the template for their own workflows or share improvements with the community.

### User Needs

- Run Claude Code autonomously without constant supervision
- Persist context across multiple iterations via git and status files
- Enforce quality gates (tests, typechecks) before accepting AI work
- Shift from reactive supervision to proactive quality design

---

## Solution Overview

### Proposed Solution

A self-contained template repository that Claude Code agents can read and understand to create and execute autonomous loops. Uses `claude` CLI with `--print` and `--dangerously-skip-permissions` flags for headless execution. Integrates with BMAD documentation for automatic loop setup.

### Key Features

- Self-documenting structure (AGENTS.md, README) that AI agents can parse
- Bash loop script adapted for `claude` CLI
- `/ralph` skill that reads BMAD docs and auto-generates loop files
- PRD-to-JSON workflow for task tracking
- Progress persistence via git history and status files
- Quality gate enforcement (tests, typechecks) before commits
- Max iteration limits and stuck detection

### Value Proposition

Type `/ralph`, Claude reads your BMAD documentation, creates all loop files, and asks if you want to start. Press yes - the loop runs autonomously until all stories pass. You focus on designing quality gates, not babysitting the AI.

---

## Business Objectives

### Goals

- Create a `/ralph` skill that automates loop creation from launch to execution
- Achieve flawless Claude Code integration with zero manual setup steps
- Enable "define PRD → run skill → autonomous execution" workflow
- Produce a clean template suitable for public sharing

### Success Metrics

- Skill successfully creates all required files (loop script, prompt, prd.json)
- Loop executes without manual intervention until completion or max iterations
- Quality gates (tests, typechecks) are enforced automatically
- End-to-end time from `/ralph` to loop start < 2 minutes

### Business Value

Personal productivity tool that demonstrates autonomous AI coding patterns. Can be shared with the Claude Code community as a reference implementation for the Ralph pattern.

---

## Scope

### In Scope

- Refactor `ralph.sh` for `claude` CLI (`--print`, `--dangerously-skip-permissions`)
- Update `prompt.md` for Claude Code context
- Refactor `/skills/ralph` to:
  - Search and read BMAD documentation from project folder
  - Auto-construct loop files (prd.json, prompt, script) from BMAD docs
- Update docs (README, AGENTS.md) for Claude Code usage
- Remove Amp-specific references
- Keep flowchart visualization

### Out of Scope

- `/skills/prd` changes - BMAD `/prd` workflow handles PRD creation
- Backward compatibility with Amp
- Changes to BMAD core workflows
- Multi-platform installers or packaging

### Future Considerations

- Integration with BMAD sprint-status.yaml for story tracking
- Multi-agent orchestration (multiple Claude instances in parallel)
- Web UI for loop monitoring
- Integration with other AI coding tools

---

## Key Stakeholders

- **jean-philippebrule (Owner)** - High influence. Sole decision-maker, primary developer, and target user.

---

## Constraints and Assumptions

### Constraints

- Must use `claude` CLI (Claude Code subscription required)
- Bash-based implementation (macOS/Linux, WSL on Windows)
- Depends on `jq` for JSON processing
- Limited by Claude's context window size

### Assumptions

- Users have Claude Code CLI installed and authenticated
- Users have git initialized in their project
- BMAD is installed (`~/.claude/config/bmad/` exists)
- Project has BMAD documentation (PRD, tech-spec, or similar) to read from
- Users understand basic git and CLI workflows

---

## Success Criteria

1. User types `/ralph`
2. Claude reads all BMAD documentation from project folder
3. Claude creates all necessary loop files (prd.json, prompt.md, loop script)
4. Claude asks: "Ready to start the loop and monitor?"
5. User confirms
6. Loop executes autonomously until ALL stories are complete, tested, and validated
7. No manual intervention required during execution
8. Template is clean enough to clone and reuse in other projects

---

## Timeline and Milestones

### Target Launch

No fixed deadline - complete when working correctly.

### Key Milestones

1. Core loop script (`ralph.sh`) refactored for `claude` CLI
2. `/ralph` skill reads BMAD documentation
3. Skill auto-generates loop files from docs
4. End-to-end flow working (launch → monitor → completion)
5. Template cleaned and ready for reuse

---

## Risks and Mitigation

- **Risk:** Context limits - large stories exceed Claude's context window
  - **Likelihood:** Medium-High
  - **Mitigation:** Enforce small, atomic stories in PRD (one feature per story). Document story sizing guidelines in AGENTS.md. Loop script detects incomplete work and flags for story splitting.

- **Risk:** Claude CLI behavior changes
  - **Likelihood:** Low
  - **Mitigation:** Pin to known-working CLI patterns. Document version requirements in README.

- **Risk:** Quality gate failures cause infinite loops
  - **Likelihood:** Medium
  - **Mitigation:** Max iteration limit. Stuck detection (same story failing 3+ times triggers exit).

---

## Next Steps

1. Create Product Requirements Document (PRD) - `/prd`
2. Design system architecture - `/architecture`
3. Begin implementation via sprint planning - `/sprint-planning`

---

**This document was created using BMAD Method v6 - Phase 1 (Analysis)**

*To continue: Run `/workflow-status` to see your progress and next recommended workflow.*
