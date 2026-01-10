---
name: ralph
description: "Autonomous loop execution for BMAD Method Phase 5. Reads all BMAD documentation, configures loop parameters, generates execution files, and runs Claude Code autonomously until all stories pass."
---

# Ralph - BMAD Autonomous Execution Workflow

Phase 5 of the BMAD Method. After completing product brief, PRD, architecture, and sprint planning, run `/ralph` to autonomously implement all stories.

---

## Workflow Overview

**Goal:** Autonomously implement all stories from BMAD planning documents

**Phase:** 5 - Autonomous Execution

**Inputs:** BMAD documentation (product brief, PRD, architecture, sprint-status, stories)

**Outputs:**
- `ralph/prd.json` - Loop state and story tracking
- `ralph/prompt.md` - Context for each Claude iteration
- `ralph/loop.sh` - Bash execution script
- `ralph/progress.txt` - Iteration log with learnings

---

## Pre-Flight: Document Ingestion

Before configuring the loop, read all available BMAD documentation.

### Step 1: Locate and Read Product Brief

**Search for:** `docs/product-brief-*.md`

**Extract from product brief:**
- Executive summary (project overview)
- Problem statement
- Proposed solution and key features
- Constraints and assumptions
- Success criteria

**Store as:** `ingested.productBrief`

```
Product Brief Found: docs/product-brief-{name}-{date}.md
- Project: {project_name}
- Type: {project_type}
- Vision: {executive_summary_first_sentence}
```

**If not found:** Display warning, continue (product brief is optional)

---

### Step 2: Locate and Read PRD

**Search for:** `docs/prd-*.md`

**Extract from PRD:**
- All functional requirements (FR-XXX sections)
  - ID, priority, description, acceptance criteria
- All non-functional requirements (NFR-XXX sections)
  - ID, priority, description, acceptance criteria
- All epics
  - ID, name, related FRs, story count estimate
- User personas
- Out of scope items

**Store as:** `ingested.prd`

```
PRD Found: docs/prd-{name}-{date}.md
- Functional Requirements: {count}
- Non-Functional Requirements: {count}
- Epics: {count}
```

**If not found:** FAIL - PRD is required for Ralph execution

---

### Step 3: Locate and Read Architecture

**Search for:** `docs/architecture-*.md`

**Extract from architecture:**
- Technology stack decisions
- Architectural patterns (e.g., "Pipeline with State Machine")
- System components and their responsibilities
- Data schemas (especially prd.json structure)
- Interface designs
- Implementation principles
- File structure conventions

**Store as:** `ingested.architecture`

```
Architecture Found: docs/architecture-{name}-{date}.md
- Pattern: {architectural_pattern}
- Tech Stack: {key_technologies}
- Components: {count}
```

**If not found for Level 2+:** FAIL - Architecture required for complex projects
**If not found for Level 0-1:** Display warning, continue

---

### Step 4: Parse Sprint Status YAML

**Search for:** `docs/sprint-status.yaml`

**Extract from sprint-status:**
- Current sprint number
- All epics with their stories
- Story details:
  - ID, title, points, status, priority, dependencies
- Sprint goals
- Metrics (completed, in_progress, not_started counts)

**Store as:** `ingested.sprintStatus`

```
Sprint Status Found: docs/sprint-status.yaml
- Current Sprint: {sprint_number}
- Total Stories: {count}
- Pending: {not_started_count}
- In Progress: {in_progress_count}
- Completed: {completed_count}
```

**If not found:** FAIL - Sprint status required for story tracking

---

### Step 5: Read Individual Story Files

**Search for:** `docs/stories/**/*.md`

**For each story file:**
- Match to sprint-status entry by story ID
- Extract full description
- Extract detailed acceptance criteria
- Extract technical notes
- Extract dependencies

**Store as:** `ingested.storyFiles`

```
Story Files Found: {count}
- Matched to sprint-status: {matched_count}
- Unmatched: {unmatched_count}
```

**If not found:** Continue with sprint-status data only (story files are optional)

---

## Document Ingestion Summary

After reading all documents, display summary:

```
╔══════════════════════════════════════════════════════════════════╗
║                    RALPH DOCUMENT INGESTION                       ║
╠══════════════════════════════════════════════════════════════════╣
║ Project: {project_name}                                           ║
║ Type: {project_type}    Level: {project_level}                    ║
╠══════════════════════════════════════════════════════════════════╣
║ Documents Found:                                                  ║
║   ✓ Product Brief: {path or "Not found (optional)"}              ║
║   ✓ PRD: {path}                                                  ║
║   ✓ Architecture: {path}                                         ║
║   ✓ Sprint Status: {path}                                        ║
║   ✓ Story Files: {count} files                                   ║
╠══════════════════════════════════════════════════════════════════╣
║ Requirements:                                                     ║
║   Functional: {fr_count}  (Must: {must}, Should: {should})       ║
║   Non-Functional: {nfr_count}                                    ║
╠══════════════════════════════════════════════════════════════════╣
║ Stories:                                                          ║
║   Total: {total}  Pending: {pending}  Done: {done}               ║
║   Epics: {epic_count}                                            ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Configuration Interview

After document ingestion, ask user to configure the loop.

### Question 1: Scope Selection

**Ask:**
> "Which stories should Ralph work on?"

**Options:**
1. All pending stories ({count} stories, {points} points)
2. Specific epic (show list)
3. Specific stories (show list)
4. Stories from current sprint only

**Store as:** `config.scope`

---

### Question 2: Quality Gates

**Ask:**
> "Configure your quality gate commands. These run after each Claude iteration."

**Collect:**
- Typecheck command (default: `npm run typecheck` or detect from package.json)
- Test command (default: `npm test`)
- Lint command (optional, default: `npm run lint`)
- Build command (optional)

**Store as:** `config.qualityGates`

---

### Question 3: Loop Parameters

**Ask:**
> "Configure loop behavior."

**Collect:**
- Max iterations (default: 50)
- Stuck threshold - failures before stopping (default: 3)
- Create feature branch? (yes/no, branch name)

**Store as:** `config.loopParams`

---

### Question 4: Custom Instructions (Optional)

**Ask:**
> "Any additional instructions for Claude during execution?"

**Examples:**
- "Focus on test coverage"
- "Use TypeScript strict mode"
- "Follow the component patterns in src/components/Button"

**Store as:** `config.customInstructions`

---

## File Generation

Generate all files needed for loop execution.

### Generate prd.json

Create `ralph/prd.json` with schema from architecture:

```json
{
  "project": "{project_name}",
  "branchName": "ralph/{feature-name}",
  "description": "{from PRD or product brief}",
  "generatedAt": "{ISO timestamp}",
  "config": {
    "maxIterations": {config.loopParams.maxIterations},
    "stuckThreshold": {config.loopParams.stuckThreshold},
    "qualityGates": {
      "typecheck": "{config.qualityGates.typecheck}",
      "test": "{config.qualityGates.test}",
      "lint": "{config.qualityGates.lint}",
      "build": "{config.qualityGates.build}"
    }
  },
  "stats": {
    "iterationsRun": 0,
    "storiesCompleted": 0,
    "startedAt": null,
    "completedAt": null
  },
  "userStories": [
    // Converted from sprint-status, ordered by dependency
  ]
}
```

### Generate prompt.md

Create `ralph/prompt.md` with project context for each iteration.

### Generate loop.sh

Create `ralph/loop.sh` executable bash script.

### Initialize progress.txt

Create `ralph/progress.txt` with header.

---

## Execution

After file generation, offer to start the loop.

**Display summary:**
```
╔══════════════════════════════════════════════════════════════════╗
║                     READY TO START RALPH                          ║
╠══════════════════════════════════════════════════════════════════╣
║ Stories: {count} to implement                                     ║
║ Quality Gates: {gates_summary}                                    ║
║ Max Iterations: {max}  Stuck Threshold: {threshold}              ║
║ Branch: {branch_name}                                            ║
╚══════════════════════════════════════════════════════════════════╝
```

**Ask:** "Ready to start the autonomous loop?"

If confirmed, execute `ralph/loop.sh` and monitor progress.

---

## Resume Detection

On invocation, check for existing `ralph/prd.json`:

### Step 1: Check for Existing State

```bash
if [ -f "ralph/prd.json" ]; then
  EXISTING_BRANCH=$(jq -r '.branchName' ralph/prd.json)
  COMPLETED=$(jq '[.userStories[] | select(.passes == true)] | length' ralph/prd.json)
  TOTAL=$(jq '.userStories | length' ralph/prd.json)
  PENDING=$((TOTAL - COMPLETED))
fi
```

### Step 2: Compare Branch Names

**If same feature (branch matches):**
- Show: "Found existing loop: {completed}/{total} stories complete ({pending} remaining)"
- Ask using AskUserQuestion:
  - Option 1: "Resume where we left off"
  - Option 2: "Start fresh (archive previous run)"
- Resume: Skip file generation, go directly to execution
- Fresh: Archive first, then regenerate files

**If different feature (branch differs):**
- Show: "Found previous run for different feature: {old_branch}"
- Archive automatically: `ralph/archive/YYYY-MM-DD-{feature-name}/`
- Proceed with new setup

### Step 3: Archive Previous Run

When archiving:

```bash
ARCHIVE_DATE=$(date +%Y-%m-%d)
FEATURE_NAME=$(echo "$EXISTING_BRANCH" | sed 's|ralph/||')
ARCHIVE_DIR="ralph/archive/${ARCHIVE_DATE}-${FEATURE_NAME}"

mkdir -p "$ARCHIVE_DIR"
mv ralph/prd.json "$ARCHIVE_DIR/"
mv ralph/progress.txt "$ARCHIVE_DIR/" 2>/dev/null || true
mv ralph/prompt.md "$ARCHIVE_DIR/" 2>/dev/null || true
mv ralph/loop.sh "$ARCHIVE_DIR/" 2>/dev/null || true

echo "Archived previous run to: $ARCHIVE_DIR"
```

### Resume Flow

When resuming:
1. Skip document ingestion (already in prd.json)
2. Skip configuration interview (already in prd.json)
3. Skip file generation (files exist)
4. Update prompt.md with fresh progress context (last 3 entries from progress.txt)
5. Go directly to execution

---

## Signals

The loop script watches for these signals from Claude:

- `<complete>ALL_STORIES_PASSED</complete>` - All done, exit success
- `<stuck>STORY_ID: reason</stuck>` - Cannot complete, increment attempts

---

## Exit Conditions

| Condition | Exit Code | Message |
|-----------|-----------|---------|
| All stories pass | 0 | COMPLETE |
| Story stuck (N failures) | 1 | STUCK: Story {ID} failed {N} times |
| Max iterations reached | 2 | MAX_ITERATIONS: {completed}/{total} stories |
| User interrupt (Ctrl+C) | 130 | INTERRUPTED |

---

## Dependencies

**Required:**
- Claude Code CLI (`claude` command available)
- `jq` for JSON processing
- `git` for commits and branches
- BMAD documentation (PRD, architecture, sprint-status)

**Optional:**
- `yq` for YAML processing (improves sprint-status updates)

---

## Example Execution

```bash
# User runs the skill
/ralph

# Ralph reads all BMAD docs
# Ralph displays summary
# Ralph asks configuration questions
# Ralph generates files
# Ralph asks to confirm
# Ralph starts loop.sh
# Loop runs until complete/stuck/max

# Final output
╔══════════════════════════════════════════════════════════════════╗
║                      RALPH COMPLETE                               ║
╠══════════════════════════════════════════════════════════════════╣
║ Stories: 12/12 passed                                             ║
║ Iterations: 18                                                    ║
║ Duration: 2h 34m                                                  ║
║ Branch: ralph/task-status                                         ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Appendix A: PRD Parsing Details

When reading the PRD, extract sections using these patterns:

### Functional Requirements
Look for sections matching `### FR-{ID}: {Title}` and extract:
```
ID: FR-001 (from heading)
Title: (from heading after colon)
Priority: (line starting with **Priority:**)
Description: (paragraph under **Description:**)
Acceptance Criteria: (checklist items under **Acceptance Criteria:**)
Dependencies: (line starting with **Dependencies:**)
```

### Non-Functional Requirements
Look for sections matching `### NFR-{ID}: {Title}` with same extraction pattern.

### Epics
Look for sections matching `### EPIC-{ID}: {Name}` and extract:
```
ID: EPIC-001 (from heading)
Name: (from heading after colon)
Description: (paragraph under **Description:**)
Functional Requirements: (list of FR-XXX references)
Story Count Estimate: (number from **Story Count Estimate:**)
Priority: (from **Priority:**)
```

### Count Summary
After parsing, count:
- Must Have FRs/NFRs (Priority contains "Must")
- Should Have FRs/NFRs (Priority contains "Should")
- Could Have FRs/NFRs (Priority contains "Could")

---

## Appendix B: Architecture Parsing Details

When reading the architecture document, extract:

### Technology Stack
Look for table under `## Technology Stack` with columns: Layer, Technology, Rationale

### System Components
Look for sections matching `### Component {N}: {Name}` and extract:
```
Name: (from heading)
Purpose: (paragraph under **Purpose:**)
Responsibilities: (bullet list under **Responsibilities:**)
FRs Addressed: (list from **FRs Addressed:**)
```

### Data Schemas
Look for JSON/code blocks under data architecture sections, especially `prd.json Schema`.

### Patterns
Extract the architectural pattern from the `### Architectural Pattern` section.

---

## Appendix C: Sprint Status YAML Structure

The sprint-status.yaml follows this structure:

```yaml
version: "6.0.0"
project_name: "ProjectName"
project_level: 3
current_sprint: 1
sprint_plan_path: "docs/sprint-plan-*.md"
last_updated: "YYYY-MM-DD"

sprints:
  - sprint_number: 1
    start_date: "YYYY-MM-DD"
    end_date: "YYYY-MM-DD"
    capacity_points: 30
    committed_points: 30
    completed_points: 0
    status: "not_started|in_progress|completed"
    goal: "Sprint goal description"
    stories:
      - story_id: "STORY-001"
        title: "Story title"
        epic_id: "EPIC-001"
        points: 3
        status: "not_started|in_progress|done"
        priority: "must_have|should_have"
        dependencies: ["STORY-XXX"]

epics:
  - epic_id: "EPIC-001"
    name: "Epic Name"
    priority: "must_have"
    total_points: 13
    stories_count: 5
    status: "not_started|in_progress|completed"

metrics:
  total_stories: 26
  total_points: 91
  stories_completed: 0
  stories_in_progress: 0
  stories_not_started: 26
```

### Extracting Stories for Ralph
1. Find stories where `status: "not_started"` or `status: "in_progress"`
2. For each story, collect: story_id, title, epic_id, points, dependencies
3. Order by sprint_number, then by dependency order within sprint

---

## Appendix D: Story Conversion to prd.json

Convert sprint-status stories to prd.json userStories array:

**From sprint-status:**
```yaml
- story_id: "STORY-001"
  title: "Read Product Brief Document"
  epic_id: "EPIC-001"
  points: 2
  status: "not_started"
  priority: "must_have"
  dependencies: []
```

**To prd.json:**
```json
{
  "id": "STORY-001",
  "epicId": "EPIC-001",
  "title": "Read Product Brief Document",
  "description": "As a developer, I want Ralph to find and read my product brief so that it understands the project vision and constraints.",
  "acceptanceCriteria": [
    "Locates docs/product-brief-*.md using glob pattern",
    "Extracts executive summary for project overview",
    "Extracts problem statement and solution overview",
    "Handles missing product brief gracefully (warning, not error)",
    "Typecheck passes"
  ],
  "priority": 1,
  "passes": false,
  "attempts": 0,
  "notes": "",
  "completedAt": null
}
```

**Priority Assignment:**
1. Stories with no dependencies get lowest numbers (first)
2. Stories with dependencies get higher numbers (after dependencies)
3. Within same dependency level, order by sprint position

**Description Generation:**
- If story file exists in `docs/stories/`, use its description
- Otherwise, generate from title: "As a developer, I want {action implied by title} so that {benefit from epic}."

**Acceptance Criteria:**
- If story file exists, use its criteria
- Otherwise, use criteria from sprint-plan document
- Always add "Typecheck passes" as final criterion

---

## Appendix E: Prompt Template

The generated `ralph/prompt.md` uses this structure:

```markdown
# Ralph Loop Context

## Project Overview
{Executive summary from product brief, or project description from PRD}

## Architecture Patterns
{Key patterns from architecture document}
- Pattern: {architectural_pattern}
- Tech Stack: {key_technologies}
- File Structure: {project structure if defined}

## Quality Gates
Before committing, ALL must pass:
- Typecheck: `{typecheck_command}`
- Tests: `{test_command}`
- Lint: `{lint_command}` (if configured)
- Build: `{build_command}` (if configured)

## Current Sprint Context
Epic: {current_epic_name}
Sprint Goal: {sprint_goal}
Stories Remaining: {count}

## Your Task
1. Read `ralph/prd.json` - find highest priority story where `passes: false`
2. Read `ralph/progress.txt` - check Codebase Patterns section for context
3. Verify you're on correct branch: `{branch_name}`
4. Implement the single story
5. Run quality gates
6. If all pass: commit with message `feat: {story_id} - {story_title}`
7. Update `ralph/prd.json`: set `passes: true`, add completion notes
8. Append to `ralph/progress.txt`:
   ```
   ## Iteration {N} - {Story ID}
   Completed: {what was done}
   Learning: {pattern or gotcha discovered}
   Note for next: {1-line context for next iteration}
   ```
9. Update relevant AGENTS.md with discovered patterns

## Rules
- ONE story per iteration
- Small, atomic commits
- ALL quality gates must pass before commit
- If stuck (can't complete): output `<stuck>STORY_ID: reason</stuck>`
- If all stories done: output `<complete>ALL_STORIES_PASSED</complete>`

{custom_instructions if provided}

## Progress Context
{Last 3 entries from progress.txt, or "First iteration - no previous context"}
```

---

## Appendix F: Loop Script Template

The generated `ralph/loop.sh`:

```bash
#!/bin/bash
# Ralph Loop - Generated {timestamp}
# Project: {project_name}
# Branch: {branch_name}

set -e

# Configuration
PROJECT_NAME="{project_name}"
BRANCH_NAME="{branch_name}"
MAX_ITERATIONS={max_iterations}
STUCK_THRESHOLD={stuck_threshold}
SPRINT_STATUS_FILE="{sprint_status_path}"

# Quality Gates
TYPECHECK_CMD="{typecheck_command}"
TEST_CMD="{test_command}"
LINT_CMD="{lint_command}"
BUILD_CMD="{build_command}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
GATE_LOG="$SCRIPT_DIR/.gate-output.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Track last story for stuck detection reset
LAST_STORY_ID=""

# ═══════════════════════════════════════════════════════════════════════════════
# DISPLAY FUNCTIONS (STORY-019: Real-Time Progress Display)
# ═══════════════════════════════════════════════════════════════════════════════

print_header_bar() {
  local width=70
  local completed=$(get_completed_count)
  local total=$(get_total_count)
  local pending=$((total - completed))

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC} ${BOLD}RALPH${NC} │ $PROJECT_NAME │ Branch: $BRANCH_NAME"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC} Stories: ${GREEN}$completed${NC}/${total} complete │ Pending: ${YELLOW}$pending${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
}

print_iteration_header() {
  local iteration="$1"
  local story_id="$2"
  local story_title="$3"
  local attempts="$4"

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Iteration ${BOLD}$iteration/$MAX_ITERATIONS${NC}${BLUE}: $story_id${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${DIM}Story:${NC} $story_title"
  echo -e "${DIM}Attempts:${NC} $attempts/$STUCK_THRESHOLD"
}

print_gate_results() {
  local typecheck_result="$1"
  local test_result="$2"
  local lint_result="$3"
  local build_result="$4"

  echo ""
  echo -e "${DIM}Quality Gates:${NC}"
  printf "  Typecheck: %s" "$typecheck_result"
  printf " │ Tests: %s" "$test_result"
  [ -n "$LINT_CMD" ] && printf " │ Lint: %s" "$lint_result"
  [ -n "$BUILD_CMD" ] && printf " │ Build: %s" "$build_result"
  echo ""
}

print_progress_bar() {
  local completed=$(get_completed_count)
  local total=$(get_total_count)
  local width=40
  local filled=$((completed * width / total))
  local empty=$((width - filled))

  printf "\n  Progress: ["
  printf "%${filled}s" | tr ' ' '█'
  printf "%${empty}s" | tr ' ' '░'
  printf "] %d/%d\n" "$completed" "$total"
}

print_final_summary() {
  local exit_type="$1"  # COMPLETE, STUCK, MAX_ITERATIONS, INTERRUPTED
  local completed=$(get_completed_count)
  local total=$(get_total_count)
  local iterations=$(jq '.stats.iterationsRun // 0' "$PRD_FILE")
  local started=$(jq -r '.stats.startedAt // "unknown"' "$PRD_FILE")
  local duration=""

  if [ "$started" != "unknown" ]; then
    local start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" "+%s" 2>/dev/null || echo "0")
    local now_epoch=$(date "+%s")
    local diff=$((now_epoch - start_epoch))
    local hours=$((diff / 3600))
    local mins=$(((diff % 3600) / 60))
    duration="${hours}h ${mins}m"
  fi

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
  case "$exit_type" in
    COMPLETE)
      echo -e "${CYAN}║${NC}                    ${GREEN}${BOLD}RALPH COMPLETE${NC}                                   ${CYAN}║${NC}"
      ;;
    STUCK)
      echo -e "${CYAN}║${NC}                    ${RED}${BOLD}RALPH STUCK${NC}                                      ${CYAN}║${NC}"
      ;;
    MAX_ITERATIONS)
      echo -e "${CYAN}║${NC}                ${YELLOW}${BOLD}MAX ITERATIONS REACHED${NC}                            ${CYAN}║${NC}"
      ;;
    INTERRUPTED)
      echo -e "${CYAN}║${NC}                    ${YELLOW}${BOLD}RALPH INTERRUPTED${NC}                              ${CYAN}║${NC}"
      ;;
  esac
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC} Stories:    $completed/$total passed"
  echo -e "${CYAN}║${NC} Iterations: $iterations"
  [ -n "$duration" ] && echo -e "${CYAN}║${NC} Duration:   $duration"
  echo -e "${CYAN}║${NC} Branch:     $BRANCH_NAME"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
}

log_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
  echo -e "${RED}✗ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

get_pending_count() {
  jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE"
}

get_completed_count() {
  jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE"
}

get_total_count() {
  jq '.userStories | length' "$PRD_FILE"
}

get_next_story() {
  jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].id // empty' "$PRD_FILE"
}

get_story_title() {
  local story_id="$1"
  jq -r --arg id "$story_id" '.userStories[] | select(.id == $id) | .title' "$PRD_FILE"
}

get_story_attempts() {
  local story_id="$1"
  jq -r --arg id "$story_id" '.userStories[] | select(.id == $id) | .attempts' "$PRD_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# QUALITY GATES (STORY-017: Quality Gate Execution)
# ═══════════════════════════════════════════════════════════════════════════════

run_quality_gate() {
  local name="$1"
  local cmd="$2"
  local result_var="$3"

  [ -z "$cmd" ] && { eval "$result_var='${DIM}SKIP${NC}'"; return 0; }

  echo -n "  [$name] Running... "

  # Run command and capture output
  local output
  local exit_code
  output=$(eval "$cmd" 2>&1)
  exit_code=$?

  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    eval "$result_var='${GREEN}PASS${NC}'"
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    eval "$result_var='${RED}FAIL${NC}'"

    # Log error output for debugging
    echo "--- $name FAILED ---" >> "$GATE_LOG"
    echo "$output" >> "$GATE_LOG"
    echo "--- END $name ---" >> "$GATE_LOG"

    # Show first few lines of error
    echo -e "${DIM}Error output (first 10 lines):${NC}"
    echo "$output" | head -10 | sed 's/^/    /'

    return 1
  fi
}

run_all_gates() {
  local all_pass=true
  local typecheck_result test_result lint_result build_result

  # Clear previous gate log
  > "$GATE_LOG"

  echo ""
  echo -e "${DIM}Running quality gates...${NC}"

  # Run ALL gates, even if some fail (continue to show all results)
  run_quality_gate "Typecheck" "$TYPECHECK_CMD" typecheck_result || all_pass=false
  run_quality_gate "Tests" "$TEST_CMD" test_result || all_pass=false

  if [ -n "$LINT_CMD" ]; then
    run_quality_gate "Lint" "$LINT_CMD" lint_result || all_pass=false
  else
    lint_result="${DIM}SKIP${NC}"
  fi

  if [ -n "$BUILD_CMD" ]; then
    run_quality_gate "Build" "$BUILD_CMD" build_result || all_pass=false
  else
    build_result="${DIM}SKIP${NC}"
  fi

  # Print summary line
  print_gate_results "$typecheck_result" "$test_result" "$lint_result" "$build_result"

  $all_pass
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE UPDATES
# ═══════════════════════════════════════════════════════════════════════════════

mark_story_complete() {
  local story_id="$1"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Atomic update to prd.json
  local tmp_file=$(mktemp)
  jq --arg id "$story_id" --arg ts "$timestamp" '
    .userStories = [.userStories[] | if .id == $id then .passes = true | .completedAt = $ts else . end] |
    .stats.storiesCompleted = ([.userStories[] | select(.passes == true)] | length)
  ' "$PRD_FILE" > "$tmp_file" && mv "$tmp_file" "$PRD_FILE"

  # Update sprint-status.yaml (STORY-022)
  update_sprint_status "$story_id"
}

increment_story_attempts() {
  local story_id="$1"

  local tmp_file=$(mktemp)
  jq --arg id "$story_id" '
    .userStories = [.userStories[] | if .id == $id then .attempts += 1 else . end]
  ' "$PRD_FILE" > "$tmp_file" && mv "$tmp_file" "$PRD_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SPRINT STATUS UPDATES (STORY-022: Sprint Status YAML Updates)
# ═══════════════════════════════════════════════════════════════════════════════

update_sprint_status() {
  local story_id="$1"
  local status_file="$PROJECT_ROOT/$SPRINT_STATUS_FILE"

  [ ! -f "$status_file" ] && return 0

  # Check if yq is available for proper YAML handling
  if command -v yq >/dev/null 2>&1; then
    # Use yq for proper YAML update
    local tmp_file=$(mktemp)
    yq eval "
      (.sprints[].stories[] | select(.story_id == \"$story_id\")).status = \"done\" |
      .last_updated = \"$(date +%Y-%m-%d)\" |
      .metrics.stories_completed = ([.sprints[].stories[] | select(.status == \"done\")] | length) |
      .metrics.stories_not_started = ([.sprints[].stories[] | select(.status == \"not_started\")] | length)
    " "$status_file" > "$tmp_file" && mv "$tmp_file" "$status_file"
  else
    # Fallback: use sed for simple status update (less reliable)
    local tmp_file=$(mktemp)
    sed "s/story_id: \"$story_id\"/story_id: \"$story_id\"/;
         /story_id: \"$story_id\"/{n;n;n;s/status: \"[^\"]*\"/status: \"done\"/}" \
         "$status_file" > "$tmp_file" && mv "$tmp_file" "$status_file"

    # Update last_updated date
    sed -i.bak "s/last_updated: \"[^\"]*\"/last_updated: \"$(date +%Y-%m-%d)\"/" "$status_file"
    rm -f "$status_file.bak"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# STUCK DETECTION (STORY-018: Stuck Detection and Exit Handling)
# ═══════════════════════════════════════════════════════════════════════════════

check_stuck_threshold() {
  local story_id="$1"
  local attempts=$(get_story_attempts "$story_id")

  # Reset attempts if we switched to a different story
  # (This handles the case where a story was skipped due to dependency)
  if [ -n "$LAST_STORY_ID" ] && [ "$LAST_STORY_ID" != "$story_id" ]; then
    # Different story - this is normal progression, not stuck
    # The attempts counter in prd.json is per-story, so no reset needed
    :
  fi

  LAST_STORY_ID="$story_id"

  if [ "$attempts" -ge "$STUCK_THRESHOLD" ]; then
    return 1  # Stuck
  fi
  return 0  # Not stuck
}

handle_stuck_exit() {
  local story_id="$1"
  local attempts=$(get_story_attempts "$story_id")

  print_final_summary "STUCK"
  echo ""
  log_error "Story $story_id failed $attempts consecutive times."
  echo ""
  echo "Suggestions:"
  echo "  1. Review the story - it may need to be split into smaller pieces"
  echo "  2. Check $GATE_LOG for error details"
  echo "  3. Manually fix the issue and run: ./ralph/loop.sh"
  echo "  4. Skip this story by setting 'passes: true' in prd.json"
  echo ""

  # Preserve state for debugging
  log_warning "State preserved in ralph/prd.json for debugging"
}

handle_interrupt() {
  echo ""
  print_final_summary "INTERRUPTED"
  echo ""
  log_warning "Loop interrupted. State saved - run ./ralph/loop.sh to resume."
  exit 130
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

# Trap Ctrl+C
trap 'handle_interrupt' INT

# Check dependencies
command -v jq >/dev/null 2>&1 || { log_error "jq is required but not installed"; exit 1; }
command -v claude >/dev/null 2>&1 || { log_error "claude CLI is required but not installed"; exit 1; }
command -v git >/dev/null 2>&1 || { log_error "git is required but not installed"; exit 1; }

# Check files exist
[ -f "$PRD_FILE" ] || { log_error "prd.json not found at $PRD_FILE"; exit 1; }
[ -f "$PROMPT_FILE" ] || { log_error "prompt.md not found at $PROMPT_FILE"; exit 1; }

# Initialize or update start time
jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.stats.startedAt //= $ts' "$PRD_FILE" > tmp.$$.json && mv tmp.$$.json "$PRD_FILE"

# Print startup header
print_header_bar

# Main loop
for iteration in $(seq 1 $MAX_ITERATIONS); do
  STORY_ID=$(get_next_story)

  # Check if all stories complete
  if [ -z "$STORY_ID" ]; then
    jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.stats.completedAt = $ts' "$PRD_FILE" > tmp.$$.json && mv tmp.$$.json "$PRD_FILE"
    print_final_summary "COMPLETE"
    exit 0
  fi

  STORY_TITLE=$(get_story_title "$STORY_ID")
  ATTEMPTS=$(get_story_attempts "$STORY_ID")

  # Check stuck threshold BEFORE attempting
  if ! check_stuck_threshold "$STORY_ID"; then
    handle_stuck_exit "$STORY_ID"
    exit 1
  fi

  # Print iteration header
  print_iteration_header "$iteration" "$STORY_ID" "$STORY_TITLE" "$ATTEMPTS"

  # Invoke Claude
  echo ""
  echo -e "${DIM}Invoking Claude...${NC}"
  OUTPUT=$(claude --print --dangerously-skip-permissions -p "$(cat "$PROMPT_FILE")" 2>&1) || true

  # Check for explicit completion signal
  if echo "$OUTPUT" | grep -q "<complete>ALL_STORIES_PASSED</complete>"; then
    jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.stats.completedAt = $ts' "$PRD_FILE" > tmp.$$.json && mv tmp.$$.json "$PRD_FILE"
    print_final_summary "COMPLETE"
    exit 0
  fi

  # Check for stuck signal from Claude
  if echo "$OUTPUT" | grep -q "<stuck>"; then
    STUCK_REASON=$(echo "$OUTPUT" | grep -o '<stuck>[^<]*</stuck>' | sed 's/<[^>]*>//g')
    log_warning "Claude signaled stuck: $STUCK_REASON"
    increment_story_attempts "$STORY_ID"

    # Append to progress file
    echo "" >> "$PROGRESS_FILE"
    echo "## Iteration $iteration - $STORY_ID (STUCK)" >> "$PROGRESS_FILE"
    echo "Reason: $STUCK_REASON" >> "$PROGRESS_FILE"
    echo "Attempts: $((ATTEMPTS + 1))/$STUCK_THRESHOLD" >> "$PROGRESS_FILE"

    continue
  fi

  # Run quality gates
  if run_all_gates; then
    log_success "All quality gates passed"

    # Get commit hash before commit
    git add -A
    COMMIT_OUTPUT=$(git commit -m "feat: $STORY_ID - $STORY_TITLE" --no-verify 2>&1) || true
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    echo -e "${DIM}Commit:${NC} $COMMIT_HASH"

    # Mark story complete in prd.json and sprint-status.yaml
    mark_story_complete "$STORY_ID"
    log_success "Story $STORY_ID completed"

    # Update iteration count
    jq '.stats.iterationsRun += 1' "$PRD_FILE" > tmp.$$.json && mv tmp.$$.json "$PRD_FILE"

    # Show progress bar
    print_progress_bar
  else
    log_error "Quality gates failed"
    increment_story_attempts "$STORY_ID"

    echo ""
    echo -e "${DIM}See $GATE_LOG for full error output${NC}"
  fi

  sleep 2
done

# Max iterations reached
jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.stats.completedAt = $ts' "$PRD_FILE" > tmp.$$.json && mv tmp.$$.json "$PRD_FILE"
print_final_summary "MAX_ITERATIONS"
echo ""
log_warning "Reached maximum iterations ($MAX_ITERATIONS)."
echo "Completed $(get_completed_count)/$(get_total_count) stories."
echo "Run ./ralph/loop.sh to continue."
exit 2
```

---

## Appendix G: BMAD Workflow Registration

### Workflow File Structure (STORY-024)

Create the workflow registration at `~/.claude/config/bmad/modules/bmm/workflows/ralph.md`:

```markdown
---
name: ralph
description: "Phase 5 autonomous loop execution - implements all stories from BMAD planning"
---

# Ralph - BMAD Autonomous Execution Workflow

## Workflow Overview

**Goal:** Autonomously implement all stories from BMAD planning documents

**Phase:** 5 - Autonomous Execution

**Agent:** Ralph (Autonomous Loop)

**Inputs:**
- Product Brief: `docs/product-brief-*.md`
- PRD: `docs/prd-*.md` (required)
- Architecture: `docs/architecture-*.md` (required for Level 2+)
- Sprint Status: `docs/sprint-status.yaml` (required)
- Story Files: `docs/stories/**/*.md` (optional)

**Outputs:**
- `ralph/prd.json` - Loop state and story tracking
- `ralph/prompt.md` - Context for each Claude iteration
- `ralph/loop.sh` - Executable bash script
- `ralph/progress.txt` - Iteration log with learnings
- Updated `docs/sprint-status.yaml` with completed stories

**Prerequisites:**
- PRD workflow complete
- Architecture workflow complete (Level 2+)
- Sprint Planning workflow complete

**Next Steps:** None (Phase 5 is the final phase)

---

## Pre-Flight

Per `helpers.md#Load-Workflow-Status`:
1. Check all Phase 1-4 prerequisites are complete
2. Load sprint-status.yaml to verify stories exist
3. Detect existing ralph/prd.json for resume capability

---

## Execution

See full workflow in `/skills/ralph/SKILL.md`

1. **Document Ingestion** - Read all BMAD docs
2. **Configuration Interview** - Ask scope, gates, params
3. **File Generation** - Create prd.json, prompt.md, loop.sh, progress.txt
4. **Loop Execution** - Run autonomous Claude iterations
5. **State Updates** - Update sprint-status.yaml on completion

---

## Exit Codes

| Code | Status | Meaning |
|------|--------|---------|
| 0 | COMPLETE | All stories passed quality gates |
| 1 | STUCK | Story failed N consecutive times |
| 2 | MAX_ITERATIONS | Iteration limit reached |
| 130 | INTERRUPTED | User pressed Ctrl+C |

---

## Helper References

- **Load status:** `helpers.md#Load-Workflow-Status`
- **Load sprint status:** `helpers.md#Load-Sprint-Status`
- **Update sprint status:** `helpers.md#Update-Sprint-Status`
```

### Workflow Status Integration (STORY-025)

Add Ralph to the bmm-workflow-status.yaml template:

```yaml
# Add to workflow_status section after sprint-status entry:

  # Phase 5: Autonomous Execution
  - name: ralph
    phase: 5
    status: "required"  # After sprint-planning complete
    description: "Autonomous loop execution for BMAD Phase 5"
    prerequisites:
      - prd
      - architecture  # For Level 2+
      - sprint-planning
```

Update `helpers.md#Determine-Next-Workflow` to recommend Ralph after sprint-planning:

```markdown
### After sprint-planning complete:

**All Levels:**
> "✓ Sprint planning complete!
>
> Next: Autonomous Implementation (Phase 5)
> Run /ralph to start autonomous loop execution.
>
> Ralph will:
> - Read all your BMAD documentation
> - Configure quality gates and loop parameters
> - Run Claude iterations until all stories pass
>
> Estimated: {story_count} stories, ~{story_count * 2} iterations"
```

### Distribution Package (STORY-026)

Create installer script at `ralph/install.sh`:

```bash
#!/bin/bash
# Ralph Installer
# Installs Ralph as a BMAD Method Phase 5 workflow

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "${BLUE}→ $1${NC}"; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      RALPH INSTALLER                                  ║${NC}"
echo -e "${BLUE}║              BMAD Method Phase 5 - Autonomous Execution              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for Claude Code config directory
CLAUDE_CONFIG="$HOME/.claude/config"
BMAD_DIR="$CLAUDE_CONFIG/bmad"

if [ ! -d "$BMAD_DIR" ]; then
  log_error "BMAD not found at $BMAD_DIR"
  echo "Please install BMAD Method first: https://github.com/bmad-method/bmad"
  exit 1
fi

log_info "Found BMAD installation at $BMAD_DIR"

# Determine source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"

# Check for required files
if [ ! -f "$SOURCE_DIR/skills/ralph/SKILL.md" ]; then
  log_error "SKILL.md not found in $SOURCE_DIR/skills/ralph/"
  exit 1
fi

# Create skills directory if needed
SKILLS_DIR="$BMAD_DIR/skills/ralph"
mkdir -p "$SKILLS_DIR"

# Copy skill file
log_info "Installing Ralph skill..."
cp "$SOURCE_DIR/skills/ralph/SKILL.md" "$SKILLS_DIR/SKILL.md"
log_success "Installed SKILL.md"

# Create workflow file
WORKFLOW_DIR="$BMAD_DIR/modules/bmm/workflows"
mkdir -p "$WORKFLOW_DIR"

log_info "Creating BMAD workflow registration..."
cat > "$WORKFLOW_DIR/ralph.md" << 'WORKFLOW_EOF'
---
name: ralph
description: "Phase 5 autonomous loop execution - implements all stories from BMAD planning"
---

# Ralph - BMAD Autonomous Execution Workflow

Phase 5 of the BMAD Method. After completing product brief, PRD, architecture,
and sprint planning, run `/ralph` to autonomously implement all stories.

See `~/.claude/config/bmad/skills/ralph/SKILL.md` for full workflow.
WORKFLOW_EOF
log_success "Created workflow file"

# Check dependencies
echo ""
log_info "Checking dependencies..."

if command -v jq >/dev/null 2>&1; then
  log_success "jq installed ($(jq --version))"
else
  log_error "jq not installed - required for Ralph"
  echo "  Install with: brew install jq (macOS) or apt install jq (Linux)"
fi

if command -v claude >/dev/null 2>&1; then
  log_success "Claude CLI installed"
else
  log_error "Claude CLI not installed - required for Ralph"
  echo "  Install with: npm install -g @anthropic-ai/claude-code"
fi

if command -v yq >/dev/null 2>&1; then
  log_success "yq installed (optional, for better YAML handling)"
else
  echo -e "${YELLOW}⚠ yq not installed (optional)${NC}"
  echo "  Install with: brew install yq (macOS) for better sprint-status.yaml updates"
fi

# Done
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    RALPH INSTALLED SUCCESSFULLY                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Usage:"
echo "  1. Complete BMAD Phases 1-4 (product-brief, PRD, architecture, sprint-planning)"
echo "  2. Run: /ralph"
echo "  3. Follow the configuration interview"
echo "  4. Let Ralph implement your stories autonomously!"
echo ""
echo "Documentation: $SKILLS_DIR/SKILL.md"
```

### Package Structure

```
ralph/
├── README.md                    # User documentation
├── install.sh                   # Installer script
├── skills/
│   └── ralph/
│       └── SKILL.md             # Main skill file
└── examples/
    ├── prd.json.example         # Example state file
    ├── prompt.md.example        # Example prompt template
    └── loop.sh.example          # Example loop script
```
