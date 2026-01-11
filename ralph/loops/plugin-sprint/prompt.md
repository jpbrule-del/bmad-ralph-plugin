# Ralph Loop Context

## Project Overview
bmad-ralph-plugin is implementing: Deliver BMAD Ralph Plugin with full Claude Code integration

See `README.md` for project overview and structure.

## Current Sprint Context
Sprint Goal: Deliver BMAD Ralph Plugin with full Claude Code integration
All Epics

## Your Task
1. Read `docs/sprint-status.yaml` - find next story where `status: "not-started"` or `status: "in-progress"`
2. Read `progress.txt` - check for context from previous iterations
3. Verify you're on correct branch: `main`
4. Implement the single story following the architecture patterns
5. Run quality gates (see below)
6. If all pass: commit with message `feat: {story_id} - {story_title}`
7. Update `docs/sprint-status.yaml`: set story `status: "completed"`
8. Update `config.json`: increment `stats.storiesCompleted`
9. Append to `progress.txt`:
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
- Use ShellCheck for bash script linting (if applicable)
- Write tests for new functionality (if applicable)

## Quality Gates
Before committing, ALL must pass:
- Lint: `npm run lint`
- Build: `npm run build`

## Data Schemas

### config.json Schema
Configuration and tracking for this loop:
```json
{
  "project": "bmad-ralph-plugin",
  "branchName": "main",
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

## Documentation References
- Sprint Status: `docs/sprint-status.yaml`
- Loop Config: `config.json` (in loop directory)
- Progress Log: `progress.txt` (in loop directory)

## Commit Message Convention
All commits must follow this format:
```
feat: {STORY_ID} - {Story Title}
```

Example:
```
feat: STORY-042 - Implement user authentication
```

## Progress Context
Check `progress.txt` for patterns discovered in previous iterations.
