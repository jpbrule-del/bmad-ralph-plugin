---
name: ralph
description: "Autonomous loop execution for BMAD Method Phase 5. Reads all BMAD documentation, configures loop parameters, generates execution files, and runs Claude Code autonomously until all stories pass. Triggers on: /ralph command, autonomous implementation, run ralph loop, execute stories"
---

# Ralph - BMAD Autonomous Execution Agent

Ralph is the autonomous execution engine for the BMAD Method, operating in Phase 5 (Implementation) to automatically implement all planned stories from BMAD sprint planning.

---

## Agent Activation

Ralph is activated by:

- **Direct invocation:** `/ralph` command in Claude Code
- **CLI invocation:** `ralph run <loop-name>` from terminal
- **Natural language:** Phrases like "run ralph loop", "autonomous implementation", "execute stories autonomously"

### When to Use Ralph

Use Ralph after completing BMAD Phases 1-4:
- ✅ Phase 1: Product Brief created
- ✅ Phase 2: PRD (Product Requirements Document) completed
- ✅ Phase 3: Architecture designed
- ✅ Phase 4: Sprint planning finished with `docs/sprint-status.yaml`

Ralph takes over at Phase 5 to autonomously implement all planned stories.

---

## Agent Responsibilities

### Primary Goal
Autonomously implement all user stories from BMAD sprint planning documents with full quality gate validation.

### BMAD Phase
**Phase 5:** Autonomous Execution

### Inputs Required
Ralph reads the following BMAD documentation:

1. **`docs/sprint-status.yaml`** (required)
   - All epics and stories with IDs, titles, points, status
   - Acceptance criteria per story
   - Sprint goals and metrics

2. **`docs/prd-*.md`** (required)
   - Functional requirements (FR-XXX)
   - Non-functional requirements (NFR-XXX)
   - Epic definitions

3. **`docs/architecture-*.md`** (recommended)
   - Technology stack
   - Architectural patterns
   - System components and data schemas
   - Implementation principles

4. **`docs/product-brief-*.md`** (optional)
   - Project vision and context
   - Problem statement and constraints

5. **`bmad/config.yaml`** (optional)
   - Project-level BMAD configuration
   - Custom paths and settings

### Outputs Generated

Ralph creates and maintains these files:

1. **`ralph/loops/<loop-name>/prd.json`**
   - Loop configuration and state
   - Story tracking with attempt counts
   - Execution statistics

2. **`ralph/loops/<loop-name>/prompt.md`**
   - Context prompt for each Claude iteration
   - Quality gates and commit conventions

3. **`ralph/loops/<loop-name>/loop.sh`**
   - Bash orchestration script
   - Claude CLI integration

4. **`ralph/loops/<loop-name>/progress.txt`**
   - Iteration log with learnings
   - Quality gate results
   - Story completion history

5. **Updated `docs/sprint-status.yaml`**
   - Story status transitions (not-started → completed)
   - Epic completed_points updates

---

## Core Capabilities

### 1. Loop Creation
- Analyzes `docs/sprint-status.yaml` to identify pending stories
- Supports epic filtering for focused execution
- Interactive configuration (max iterations, stuck threshold, quality gates)
- Generates all required loop files from templates
- Creates isolated git branch (`ralph/<loop-name>`)

### 2. Autonomous Execution
- Runs Claude Code CLI iterations with fresh context per iteration
- Implements one story at a time, in priority order
- Executes configured quality gates after each story
- Auto-commits successful implementations
- Updates sprint status and progress logs

### 3. Quality Assurance
- Configurable quality gates: typecheck, test, lint, build
- Fails story if any gate fails
- Claude receives failure feedback and retries
- Stuck detection after threshold attempts (default: 3)

### 4. Progress Monitoring
- Real-time dashboard with `ralph status <loop-name>`
- Progress visualization with completion percentages
- ETA calculation based on historical pace
- Quality gate status display
- Recent activity log tail

### 5. Loop Management
- List all loops: `ralph list`
- Show loop details: `ralph show <loop-name>`
- Archive completed loops: `ralph archive <loop-name>`
- Clone loops: `ralph clone <source> <destination>`
- Resume interrupted loops: `ralph run <loop-name>`

### 6. Feedback Collection
- Mandatory feedback questionnaire on archive
- Satisfaction scores (1-5 scale)
- What worked well / what should improve
- Aggregate analytics: `ralph feedback-report`

---

## Workflow Summary

```
1. ralph create <loop-name>
   └─> Reads docs/sprint-status.yaml
   └─> Prompts for configuration
   └─> Generates loop files
   └─> Creates git branch

2. ralph run <loop-name>
   └─> For each pending story:
       ├─> Run Claude Code CLI with prompt.md
       ├─> Claude implements story
       ├─> Execute quality gates
       ├─> If pass: commit + mark complete
       └─> If fail: increment attempts, retry

3. ralph status <loop-name>
   └─> Monitor progress in real-time

4. ralph archive <loop-name>
   └─> Collect feedback
   └─> Move to archive with timestamp
```

---

## Integration Points

### With BMAD Method
- Reads BMAD documentation (Phases 1-3)
- Updates sprint-status.yaml (Phase 4)
- Operates autonomously in Phase 5

### With Claude Code CLI
- Spawns fresh Claude sessions per iteration
- Passes structured context via prompt.md
- Captures output for completion detection

### With Git
- Creates feature branches automatically
- Commits successful implementations
- Maintains clean git history

### With Project Build System
- Integrates with npm/yarn scripts
- Runs project-specific quality gates
- Validates before every commit

---

## Configuration

### Global Configuration
**Location:** `ralph/config.yaml` or `ralph/config.json`

```yaml
qualityGates:
  typecheck: "npm run typecheck"
  test: "npm test"
  lint: "npm run lint"
  build: "npm run build"
```

### Loop Configuration
**Location:** `ralph/loops/<loop-name>/prd.json`

```json
{
  "config": {
    "maxIterations": 50,
    "stuckThreshold": 3,
    "qualityGates": { /* enabled gates */ }
  }
}
```

---

## Dependencies

### Required Tools
- **Claude Code CLI:** Must be installed and authenticated
- **jq:** JSON processing (1.6+)
- **yq:** YAML processing (v4.x)
- **git:** Version control (v2.x+)
- **bash:** Shell environment (4.0+)

### Required Documentation
- `docs/sprint-status.yaml` - Story definitions and tracking
- `docs/prd-*.md` - Functional requirements

### Optional Documentation
- `docs/architecture-*.md` - Architecture patterns
- `docs/product-brief-*.md` - Project vision
- `bmad/config.yaml` - BMAD configuration

---

## Exit Conditions

Ralph stops execution when:

1. **All stories completed:** `<complete>ALL_STORIES_PASSED</complete>`
2. **Story stuck:** Attempts exceed threshold (default: 3)
3. **Max iterations reached:** Safety limit hit
4. **User interrupt:** Ctrl+C (graceful shutdown with state preservation)

---

## Best Practices

### Story Sizing
- Keep stories small enough for single iteration completion
- Target: 1-3 points per story
- Split large stories (5-8 points) into smaller tasks

### Quality Gates
- Always enable at least one gate (recommend: lint + build)
- Project-specific gates ensure code standards
- Failed gates provide feedback for next iteration

### Loop Management
- Use epic filtering for focused work
- Archive completed loops for history
- Clone successful configurations for reuse

### Monitoring
- Check `ralph status` during execution
- Review `progress.txt` for learnings
- Analyze feedback reports for improvements

---

## Troubleshooting

### Loop Won't Start
- Verify `ralph init` was run
- Check `docs/sprint-status.yaml` exists
- Ensure no other loop is running (check for `.lock` file)

### Story Keeps Failing
- Review quality gate output in `progress.txt`
- Check if acceptance criteria are clear
- Consider increasing stuck threshold
- May require manual intervention

### Git Conflicts
- Ralph creates isolated branches
- Merge conflicts handled manually
- Use `ralph show` to see branch name

---

## Version

Agent Version: 1.0.0
BMAD Phase: 5 (Autonomous Execution)
Last Updated: 2026-01-10
