---
name: ralph
type: autonomous-loop
phase: 5
description: "Autonomous loop execution agent for BMAD Method Phase 5. Implements all stories from sprint planning through repeated Claude Code CLI iterations."
version: "1.0.0"
---

# Ralph Agent

## Agent Overview

Ralph is an autonomous execution agent that implements the final phase of the BMAD Method. After completing product brief, PRD, architecture, and sprint planning, Ralph takes over to autonomously implement all planned stories through repeated Claude Code CLI iterations.

**Agent Type:** Autonomous Loop Executor

**BMAD Phase:** 5 - Autonomous Execution

**Invocation:** `/ralph`

---

## Agent Activation

### When to Activate

Ralph should be invoked when:

1. **BMAD Phases 1-4 are complete:**
   - ✓ Product Brief exists (`docs/product-brief-*.md`)
   - ✓ PRD exists (`docs/prd-*.md`)
   - ✓ Architecture exists (`docs/architecture-*.md`) (Level 2+)
   - ✓ Sprint Status exists (`docs/sprint-status.yaml`)

2. **Stories are ready for implementation:**
   - Sprint planning has generated user stories
   - Stories have acceptance criteria
   - Dependencies are documented

3. **Quality gates are configured:**
   - Test commands are defined
   - Lint/typecheck commands are available
   - Build process is in place

### Trigger Conditions

**Primary Trigger:**
```
User runs: /ralph
```

**Prerequisites Check:**
- Verify docs/sprint-status.yaml exists
- Verify docs/prd-*.md exists
- Verify project has git repository initialized
- Check for pending stories (status != "completed")

**Resume Detection:**
- If `ralph/config.json` exists, offer to resume existing loop
- If `ralph/archive/` contains previous runs, offer to clone configuration

---

## Agent Responsibilities

### 1. Document Ingestion (Pre-Flight)

**Primary Responsibility:** Read and understand all BMAD documentation

**Actions:**
- Locate and parse product brief (`docs/product-brief-*.md`)
- Load PRD with all functional and non-functional requirements
- Read architecture document for patterns and tech stack
- Parse sprint-status.yaml for story details
- Load individual story files from `docs/stories/` if present

**Output:** Comprehensive project context stored in memory for configuration

**Success Criteria:**
- All required documents located and parsed
- Story dependencies mapped
- Epic structure understood
- Requirements extracted

### 2. Configuration Interview

**Primary Responsibility:** Gather user preferences for loop execution

**Actions:**
- Prompt for scope selection (all stories / specific epic / specific stories)
- Collect quality gate commands (typecheck, test, lint, build)
- Configure loop parameters (max iterations, stuck threshold)
- Gather custom instructions for Claude iterations
- Offer to create feature branch

**Output:** Complete configuration stored in `ralph/config.json`

**Success Criteria:**
- All configuration questions answered
- Quality gates validated as executable commands
- Loop parameters within reasonable bounds
- User confirms configuration before proceeding

### 3. File Generation

**Primary Responsibility:** Generate all files needed for autonomous execution

**Actions:**
- Generate `ralph/config.json` with loop configuration and story tracking
- Generate `ralph/prompt.md` with context for Claude iterations
- Generate `ralph/loop.sh` executable orchestration script
- Initialize `ralph/progress.txt` iteration log

**Output:** Complete loop directory at `ralph/loops/<name>/` or `ralph/`

**Success Criteria:**
- All files created with correct permissions
- loop.sh is executable
- config.json validates as proper JSON
- prompt.md contains all necessary context

### 4. Autonomous Loop Execution

**Primary Responsibility:** Run Claude Code CLI iterations until stories complete

**Actions:**
- Execute loop.sh orchestration script
- For each iteration:
  - Invoke `claude --print --dangerously-skip-permissions` with prompt
  - Capture Claude's implementation output
  - Run quality gates (typecheck, test, lint, build)
  - Commit changes if gates pass
  - Update sprint-status.yaml with completion
  - Log iteration to progress.txt
- Handle stuck detection (story fails N times)
- Handle interruption gracefully (Ctrl+C)
- Track execution statistics

**Output:**
- Implemented stories with passing quality gates
- Git commits for each completed story
- Updated sprint-status.yaml
- Detailed progress.txt log

**Success Criteria:**
- Stories marked as completed in sprint-status.yaml
- All quality gates pass before commits
- Git history shows atomic commits per story
- Progress log contains learnings and patterns

### 5. State Management

**Primary Responsibility:** Maintain accurate state throughout execution

**Actions:**
- Track story attempts in config.json
- Record completion timestamps
- Update story status in both config.json and sprint-status.yaml
- Maintain iteration counter
- Calculate execution statistics

**Output:** Always-consistent state files

**Success Criteria:**
- State survives interruption (Ctrl+C)
- Resume capability works correctly
- No partial writes or corrupted JSON/YAML
- Atomic file operations prevent data loss

---

## Agent Configuration

### Required Configuration

**Project Configuration:**
```yaml
project_name: string          # Project identifier
branch_name: string           # Git branch for loop work
sprint_status_path: string    # Path to sprint-status.yaml
```

**Loop Parameters:**
```yaml
max_iterations: integer       # Default: 50, Range: 1-999
stuck_threshold: integer      # Default: 3, Range: 1-10
```

**Quality Gates:**
```yaml
quality_gates:
  typecheck: string|null      # Command to run typecheck (e.g., "npm run typecheck")
  test: string|null           # Command to run tests (e.g., "npm test")
  lint: string|null           # Command to run linter (e.g., "npm run lint")
  build: string|null          # Command to build project (e.g., "npm run build")
```

**Optional Configuration:**
```yaml
custom_instructions: string|null  # Additional instructions for Claude iterations
epic_filter: string|null          # Limit to specific epic ID (e.g., "EPIC-001")
```

### Configuration File Location

**Global Configuration:**
```
ralph/config.yaml             # Global defaults for new loops
```

**Loop-Specific Configuration:**
```
ralph/loops/<name>/config.json  # Per-loop configuration and state
```

**BMAD Project Configuration:**
```
bmad/config.yaml              # BMAD project settings (paths, etc.)
```

### Environment Variables

Ralph respects these environment variables:

```bash
RALPH_MAX_ITERATIONS=50       # Override default max iterations
RALPH_STUCK_THRESHOLD=3       # Override default stuck threshold
EDITOR=vim                    # Editor for `ralph edit` command
NO_COLOR=1                    # Disable colored terminal output
```

---

## Agent Output

### Primary Outputs

1. **Implemented Stories**
   - Location: Working directory (as code changes)
   - Format: Source code files, tests, documentation
   - Updates: Committed to git with atomic commits

2. **Loop State**
   - Location: `ralph/config.json`
   - Format: JSON
   - Content: Story attempts, completion status, execution stats

3. **Iteration Log**
   - Location: `ralph/progress.txt`
   - Format: Plain text (markdown-style)
   - Content: Per-iteration summaries, learnings, patterns

4. **Sprint Status Updates**
   - Location: `docs/sprint-status.yaml`
   - Format: YAML
   - Content: Story status changes, epic progress, metrics

### Exit Codes

| Code | Status | Meaning |
|------|--------|---------|
| 0 | SUCCESS | All stories completed and passed quality gates |
| 1 | STUCK | Story failed N consecutive times |
| 2 | MAX_ITERATIONS | Reached iteration limit with stories remaining |
| 130 | INTERRUPTED | User interrupted with Ctrl+C |

---

## Agent Dependencies

### Required Dependencies

**System Tools:**
- `bash` 4.0+ (shell environment)
- `jq` 1.6+ (JSON processing)
- `git` 2.x+ (version control)
- `claude` (Claude Code CLI)

**Optional Dependencies:**
- `yq` 4.x (YAML processing, improves sprint-status updates)

### BMAD Dependencies

**Required BMAD Outputs:**
- PRD document (`docs/prd-*.md`)
- Sprint Status file (`docs/sprint-status.yaml`)

**Optional BMAD Outputs:**
- Product Brief (`docs/product-brief-*.md`)
- Architecture document (`docs/architecture-*.md`)
- Individual story files (`docs/stories/**/*.md`)

---

## Agent Integration

### BMAD Workflow Integration

**Workflow Position:** Phase 5 (final phase)

**Prerequisite Workflows:**
1. Product Brief (Phase 1)
2. PRD (Phase 2)
3. Architecture (Phase 3)
4. Sprint Planning (Phase 4)

**Next Workflows:** None (Ralph is the terminal phase)

### Invocation Methods

**Primary Invocation:**
```bash
/ralph                        # Interactive workflow with configuration
```

**Direct CLI Invocation:**
```bash
npx @ralph/cli create sprint-1    # Create a loop
npx @ralph/cli run sprint-1       # Run a loop
npx @ralph/cli status sprint-1    # Monitor loop status
```

**Programmatic Invocation:**
```bash
cd ralph/loops/sprint-1 && ./loop.sh  # Run loop script directly
```

### State Persistence

**Resume Capability:**
- Ralph automatically detects existing `ralph/config.json`
- Offers to resume from last completed story
- Preserves attempt counts across runs

**Archive System:**
- Completed loops can be archived to `ralph/archive/`
- Archived loops include feedback questionnaire
- Archives serve as historical record and learning base

---

## Agent Capabilities

### What Ralph Can Do

✓ Read and understand BMAD documentation (PRD, architecture, stories)
✓ Generate loop configuration and execution files
✓ Invoke Claude Code CLI autonomously for story implementation
✓ Run quality gates (typecheck, test, lint, build)
✓ Make atomic git commits for completed stories
✓ Update sprint-status.yaml with progress
✓ Handle interruption gracefully with state preservation
✓ Detect stuck stories and halt for human intervention
✓ Resume execution from previous state
✓ Archive completed loops with feedback

### What Ralph Cannot Do

✗ Modify or create BMAD documentation (PRD, architecture)
✗ Change story definitions or acceptance criteria
✗ Deploy or release code to production
✗ Interact with external APIs or services (unless via quality gates)
✗ Make subjective decisions about implementation approach
✗ Override quality gate failures

---

## Agent Examples

### Example 1: Basic Invocation

```bash
# User completes BMAD Phases 1-4
# User invokes Ralph
/ralph

# Ralph performs document ingestion
# Ralph asks configuration questions
# Ralph generates loop files
# Ralph executes autonomous loop
# Ralph completes all stories
```

**Expected Output:**
```
╔══════════════════════════════════════════════════════════════════════╗
║                      RALPH COMPLETE                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║ Stories: 12/12 passed                                                 ║
║ Iterations: 18                                                        ║
║ Duration: 2h 34m                                                      ║
║ Branch: ralph/sprint-1                                                ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Example 2: Resume After Interruption

```bash
# User starts Ralph
/ralph

# Loop runs for several iterations
# User presses Ctrl+C to interrupt

# Later, user resumes
/ralph

# Ralph detects existing state
# Offers: "Resume where we left off? (Y/n)"
# User confirms
# Ralph continues from next story
```

### Example 3: Epic-Specific Execution

```bash
# User wants to implement only EPIC-001
/ralph

# During configuration interview:
# "Which stories should Ralph work on?"
# User selects: "2. Specific epic"
# Ralph shows epic list
# User selects: "EPIC-001"

# Ralph implements only stories from EPIC-001
```

---

## Agent Monitoring

### Real-Time Monitoring

**Status Command:**
```bash
npx @ralph/cli status <loop-name>
```

**Dashboard Features:**
- Overall progress (completed/total stories)
- Current story being worked on
- Iteration counter (current/max)
- Quality gate status (pass/fail indicators)
- Estimated time to completion
- Recent activity log tail

**Refresh Rate:** 2 seconds (configurable with --refresh flag)

**Keyboard Controls:**
- `q` - Quit dashboard
- `r` - Manual refresh
- `l` - View full log

### Progress Files

**progress.txt Structure:**
```
# Ralph Progress Log
# Project: {project_name}
# Branch: {branch_name}
# Started: {timestamp}

## Iteration 1 - STORY-001
Completed: {what was done}
Learning: {pattern or gotcha discovered}
Note for next: {1-line context for next iteration}

## Iteration 2 - STORY-002
...
```

---

## Agent Patterns

### Design Patterns

**1. Atomic File Operations**
- All state writes use temp-file + rename pattern
- Prevents corruption on crash or interruption
- Example: `jq '...' file.json > tmp.$$.json && mv tmp.$$.json file.json`

**2. Modular Command Structure**
- Each command in separate file (`lib/commands/*.sh`)
- Commands lazy-load dependencies
- Clear separation of concerns

**3. Idempotent Operations**
- `ralph init` can run multiple times safely
- State updates are safe to retry
- Quality gates are side-effect free

**4. Progressive Enhancement**
- Works with minimal dependencies (jq, git, claude)
- Enhanced with optional dependencies (yq for better YAML handling)
- Graceful degradation when optional tools missing

### Best Practices

**For Users:**
1. Complete BMAD Phases 1-4 thoroughly before invoking Ralph
2. Ensure quality gates are properly configured and tested
3. Use realistic stuck threshold (3-5 attempts)
4. Monitor first few iterations to catch configuration issues
5. Review progress.txt for learnings and patterns

**For Developers:**
1. Always use atomic writes for state files
2. Log all major events to progress.txt
3. Handle interruption gracefully (trap INT)
4. Validate inputs before execution
5. Provide clear error messages with suggested remediation

---

## Agent Troubleshooting

### Common Issues

**Issue 1: Ralph Cannot Find sprint-status.yaml**

**Symptoms:**
```
✗ docs/sprint-status.yaml not found
```

**Resolution:**
1. Verify BMAD Phase 4 (Sprint Planning) completed
2. Check bmad/config.yaml for custom sprint_status_file path
3. Run sprint planning workflow first

**Issue 2: Quality Gates Keep Failing**

**Symptoms:**
```
✗ Quality gates failed
  [Typecheck] FAIL
```

**Resolution:**
1. Check `ralph/.gate-output.log` for detailed errors
2. Verify quality gate commands work manually
3. Consider adjusting stuck threshold if gates are too strict
4. Review custom_instructions for conflicting guidance

**Issue 3: Loop Gets Stuck on Same Story**

**Symptoms:**
```
✗ Story STORY-015 failed 3 consecutive times.
```

**Resolution:**
1. Review progress.txt for failure patterns
2. Check if story is too large (split into smaller stories)
3. Add clarifying custom instructions
4. Manually implement story and mark complete
5. Skip story temporarily: set `"status": "completed"` in sprint-status.yaml

---

## Agent Versioning

**Current Version:** 1.0.0

**Versioning Scheme:** Semantic Versioning (semver)

**Version History:**
- `1.0.0` - Initial release with full BMAD Phase 5 support

**Compatibility:**
- BMAD Method: v6.0.0+
- Claude Code CLI: Latest
- Node.js: Not required (bash-based)

---

## Agent Metadata

**Author:** BMAD Method Contributors
**License:** MIT
**Repository:** https://github.com/bmad-method/ralph
**Documentation:** See `packages/skills/ralph/SKILL.md` for full workflow specification
**Support:** GitHub Issues

---
