# Ralph Loop Context

## Project Overview
Ralph is a BMAD Phase 5 autonomous execution CLI tool that automates story implementation after BMAD sprint planning. It reads all BMAD documentation, configures an autonomous loop, and executes Claude Code CLI iterations until all stories pass quality gates.

## Architecture Patterns
- **Pattern:** Modular Bash CLI with Command Routing
- **Tech Stack:** Bash 4.0+, jq 1.6+, yq 4.x, Git 2.x, Claude Code CLI
- **File Structure:**
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

## Key Implementation Principles
1. All state persists via atomic file writes (temp + rename pattern)
2. POSIX-compliant bash for macOS/Linux compatibility
3. Modular structure with lazy loading for performance
4. Git-style subcommand routing
5. Colored terminal output respecting NO_COLOR env var

## Quality Gates
Before committing, ALL must pass:
- Build: `npm run build`
- Lint: `npm run lint`

## Current Sprint Context
Sprint Goal: Deliver MVP ralph CLI with full loop lifecycle (create, run, archive)
Total Stories: 49
Total Points: 166
Epics: 7

## Your Task
1. Read `docs/sprint-status.yaml` - find next story where `status: "not-started"` or `status: "in-progress"`
2. Read `ralph/progress.txt` - check for context from previous iterations
3. Verify you're on correct branch: `ralph/sprint-1`
4. Implement the single story following the architecture patterns
5. Run quality gates: `npm run build && npm run lint`
6. If all pass: commit with message `feat: {story_id} - {story_title}`
7. Update `docs/sprint-status.yaml`: set story `status: "completed"`
8. Update `ralph/config.json`: increment `stats.storiesCompleted`
9. Append to `ralph/progress.txt`:
   ```
   ## Iteration {N} - {Story ID}
   Completed: {what was done}
   Learning: {pattern or gotcha discovered}
   Note for next: {1-line context for next iteration}
   ```

## Rules
- ONE story per iteration
- Small, atomic commits
- ALL quality gates must pass before commit
- If stuck (can't complete): output `<stuck>STORY_ID: reason</stuck>`
- If all stories done: output `<complete>ALL_STORIES_PASSED</complete>`
- Follow existing code patterns in the codebase
- Use ShellCheck for bash script linting
- Write Bats tests for new functionality

## Data Schemas

### config.json Schema
```json
{
  "project": "ralph",
  "branchName": "ralph/sprint-1",
  "config": {
    "maxIterations": 50,
    "stuckThreshold": 3,
    "qualityGates": {...}
  },
  "stats": {
    "iterationsRun": 0,
    "storiesCompleted": 0
  },
  "storyAttempts": {}
}
```

### sprint-status.yaml (single source of truth for stories)
Stories are tracked in `docs/sprint-status.yaml`. Update story status there when completing a story.

## Progress Context
First iteration - no previous context
