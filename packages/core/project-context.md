# Project Context: Ralph

> BMAD Method Phase 5 - Autonomous Execution Workflow

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Project** | Ralph |
| **Type** | BMAD Workflow / CLI Tool |
| **Level** | 3 (Complex) |
| **Pattern** | Pipeline with State Machine |
| **Status** | Complete (56/56 stories, 166 points) |
| **Sprint Duration** | ~4 hours (automated) |

---

## What Ralph Does

Ralph autonomously implements all stories from BMAD sprint planning using Claude Code CLI. After completing Phases 1-4 (product-brief, PRD, architecture, sprint-planning), users run `/ralph` to:

1. **Ingest** all BMAD documentation
2. **Validate** architecture via AI consensus dialogue
3. **Configure** loop parameters (quality gates, limits)
4. **Generate** execution files (prd.json, prompt.md, loop.sh)
5. **Execute** headless loop until all stories pass

---

## Critical Files

| File | Purpose |
|------|---------|
| `skills/ralph/SKILL.md` | Main workflow definition (1800+ lines) |
| `install.sh` | BMAD ecosystem installer |
| `ralph.sh` | Standalone bash loop runner |
| `docs/sprint-status.yaml` | Story tracking state |

### Generated at Runtime (in `ralph/` folder)

| File | Purpose |
|------|---------|
| `prd.json` | Loop state, story status, config |
| `prompt.md` | Context for each Claude iteration |
| `loop.sh` | Executable bash script |
| `progress.txt` | Append-only iteration log |
| `consensus.json` | AI dialogue audit trail |

---

## Architecture Patterns

### Core Pattern: Fresh Context Per Iteration

Each iteration spawns a **new Claude CLI instance** with clean context. Memory persists via:
- Git history (commits)
- `progress.txt` (learnings)
- `prd.json` (story status)
- `AGENTS.md` (discovered patterns)

### State Machine Flow

```
PICK_STORY → INVOKE_CLAUDE → VERIFY_GATES → UPDATE_STATE → (repeat)
                                   │
                                   ├── PASS → commit, next story
                                   └── FAIL → increment attempts, check stuck
```

### Exit Conditions

| Code | Status | Trigger |
|------|--------|---------|
| 0 | COMPLETE | All stories pass |
| 1 | STUCK | Story fails N times |
| 2 | MAX_ITERATIONS | Limit reached |
| 130 | INTERRUPTED | Ctrl+C |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Workflow | Markdown (SKILL.md) |
| Runtime | Bash |
| JSON | jq |
| VCS | Git |
| AI | Claude CLI (`--print --dangerously-skip-permissions`) |
| Optional | yq for YAML |

---

## Mandatory Rules for AI Agents

### Story Size

Stories MUST be small enough to complete in one context window:
- **Good**: Add database column, add UI component, update server action
- **Bad**: Build entire dashboard, add authentication, refactor API

### Quality Gates

ALL gates must pass before commit:
1. Typecheck
2. Tests
3. Lint (if configured)
4. Build (if configured)

### Commit Format

```
feat: STORY-XXX - Story title
```

### Progress Logging

After each iteration, append to `progress.txt`:
```markdown
## Iteration N - STORY-XXX
Completed: {what was done}
Learning: {pattern or gotcha discovered}
Note for next: {1-line context}
```

### AGENTS.md Updates

After implementation, update AGENTS.md with:
- Patterns discovered
- Gotchas found
- Useful context for future iterations

---

## Consensus Validation Phase

Before implementation, Ralph validates architecture via external AI dialogue:

1. **Round 1**: External AI (via Perplexity MCP) challenges epics
2. **Round 2**: Ralph (Claude) provides counter-arguments
3. **Round 3**: Synthesis and consensus building
4. **Round 4**: Final agreement and action items

**Hard Gate**: Critical issues must be resolved before coding begins.

---

## Signal Outputs

Claude outputs these for loop control:

| Signal | Meaning |
|--------|---------|
| `<complete>ALL_STORIES_PASSED</complete>` | All done, exit success |
| `<stuck>STORY_ID: reason</stuck>` | Cannot complete, increment attempts |

---

## File Schemas

### prd.json Structure

```json
{
  "project": "string",
  "branchName": "ralph/feature-name",
  "config": {
    "maxIterations": 50,
    "stuckThreshold": 3,
    "qualityGates": { "typecheck": "...", "test": "..." }
  },
  "stats": { "iterationsRun": 0, "storiesCompleted": 0 },
  "userStories": [{
    "id": "STORY-001",
    "passes": false,
    "attempts": 0
  }]
}
```

### sprint-status.yaml Key Paths

```yaml
sprints[].stories[].status  # "not_started" | "in_progress" | "done"
metrics.stories_completed   # count
last_updated               # "YYYY-MM-DD"
```

---

## Dependencies

**Required**:
- `jq` - JSON processing
- `claude` - Claude Code CLI
- `git` - Version control

**Optional**:
- `yq` - Better YAML handling for sprint-status updates

---

## Common Gotchas

1. **Context Overflow**: If story is too big, Claude runs out of context before finishing
2. **Stuck Loop**: Same story failing repeatedly - split into smaller pieces
3. **Quality Gate Failures**: Check `ralph/.gate-output.log` for details
4. **Resume State**: Existing `ralph/prd.json` triggers resume flow, not fresh start
5. **yq vs jq Syntax**: See section below - they are NOT interchangeable

---

## yq vs jq: Critical Syntax Differences

**WARNING**: yq (Mike Farah v4.x) and jq have different syntax. Do NOT copy patterns between them.

| Feature | jq Syntax | yq Syntax |
|---------|-----------|-----------|
| Default value | `// empty` or `// "default"` | Handle null in bash: `if [ "$result" = "null" ]` |
| Variable binding | `--arg name value` | Shell interpolation: `"$variable"` in double quotes |
| Null coalescing | `.field // "fallback"` | Not supported - check for "null" string |

### Correct yq Pattern (bash)
```bash
get_value() {
  local result
  result=$(yq -r '.field' file.yaml)
  if [ "$result" = "null" ] || [ -z "$result" ]; then
    echo "default"
  else
    echo "$result"
  fi
}
```

### Wrong (jq syntax in yq)
```bash
# BROKEN - yq doesn't support // empty
yq -r '.field // empty' file.yaml
```

---

## Pre-flight Checklist

Before starting a ralph loop, verify:

1. **Build passes**: `npm run build` (or configured build command)
2. **Lint passes**: `npm run lint` (or configured lint command)
3. **yq version**: `yq --version` should show Mike Farah v4.x
4. **Dependencies**: `jq`, `yq`, `git`, `claude` all installed
5. **Clean git state**: No uncommitted changes that could interfere

---

## Resume Behavior

When `ralph/prd.json` exists:
- **Same branch**: Offer resume or fresh start
- **Different branch**: Archive previous run to `ralph/archive/`

When resuming:
1. Skip document ingestion
2. Check consensus.json state
3. Skip configuration interview
4. Go directly to execution

---

## Installation Locations

| Path | Content |
|------|---------|
| `~/.claude/commands/bmad/ralph.md` | BMAD workflow entry |
| `~/.claude/config/bmad/skills/ralph/SKILL.md` | Full workflow docs |
| `~/.claude/skills/bmad/ralph.md` | Skill registration |

---

*Generated by BMGD generate-project-context workflow*
