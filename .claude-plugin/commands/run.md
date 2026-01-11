You are executing the **Ralph Run** command to execute an automation loop.

## Command Overview

**Purpose:** Execute a Ralph automation loop to autonomously implement BMAD sprint stories

**Agent:** Ralph CLI

**Output:** Story implementations with quality gates validation, commits, and progress tracking

---

## Execution

Run the ralph CLI run command with a loop name:

```bash
ralph run <loop-name>
```

### Required Arguments

- `<loop-name>` - Name of the loop to execute (must exist in `ralph/loops/`)

### Options

- `--dry-run` - Simulate execution without running Claude (shows configuration and pending stories)
- `--restart` - Start from beginning, ignoring any resume state

### Examples

```bash
# Run loop with default behavior (resumes from last position)
ralph run my-sprint

# Simulate execution to preview configuration and stories
ralph run my-sprint --dry-run

# Restart loop from beginning (ignore resume state)
ralph run my-sprint --restart

# Restart with fresh state (useful after fixing issues)
ralph run auth-epic --restart
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Validates loop exists in `ralph/loops/<name>`
   - Ensures loop is not archived (archived loops cannot run)
   - Verifies `config.json` exists and has valid structure
   - Checks for lock file to prevent concurrent execution

2. **Manages Git Branch**
   - Reads branch name from `config.json`
   - Checks out the loop's branch if not already on it
   - Validates branch exists before checking out
   - Ensures no uncommitted changes or conflicts

3. **Executes Loop Orchestration**
   - Executes `loop.sh` script in the loop directory
   - Loop script reads `prompt.md` context
   - Passes `--restart` flag if specified
   - Maintains lock file during execution to prevent concurrent runs
   - Removes lock file on completion or interruption

4. **Story Execution Flow** (performed by loop.sh)
   - Reads `docs/sprint-status.yaml` to find next story
   - Checks `progress.txt` for context from previous iterations
   - Implements single story following architecture patterns
   - Runs quality gates (lint, build, test, typecheck as configured)
   - Creates commit with format: `feat: {story_id} - {story_title}`
   - Updates `docs/sprint-status.yaml` to mark story as completed
   - Updates `config.json` to increment `stats.storiesCompleted`
   - Appends iteration summary to `progress.txt`
   - Continues to next story automatically

5. **Dry Run Mode** (with --dry-run flag)
   - Validates configuration structure
   - Displays loop configuration (max iterations, stuck threshold)
   - Shows quality gate commands
   - Lists pending stories to be processed
   - Displays current progress statistics
   - Does NOT execute any stories or modify files

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loop must exist (`ralph create <name>`)
- Loop must not be archived
- Git must be available (for branch checkout)
- Quality gate commands must be valid (npm scripts should exist)
- `docs/sprint-status.yaml` must be valid and accessible

### Quality Gates

After each story implementation, the loop runs configured quality gates:

- **typecheck** - Type checking (if configured, e.g., `npx tsc --noEmit`)
- **test** - Test suite (if configured, e.g., `npm test`)
- **lint** - Code linting (e.g., `npm run lint`)
- **build** - Project build (e.g., `npm run build`)

All enabled quality gates must pass before the story is committed. If any gate fails, the story remains in-progress and requires manual intervention.

### Stuck Detection

The loop monitors for stuck stories:

- **Stuck Threshold** - Number of consecutive failed attempts before marking story as stuck (default: 3)
- **Max Iterations** - Maximum total iterations before stopping loop (default: 50)

If a story exceeds the stuck threshold, the loop pauses and outputs:
```
<stuck>STORY_ID: reason</stuck>
```

If all stories are completed successfully, the loop outputs:
```
<complete>ALL_STORIES_PASSED</complete>
```

### Progress Tracking

The loop maintains detailed progress in `progress.txt`:

```
## Iteration {N} - {Story ID}
Completed: {what was done}
Learning: {pattern or gotcha discovered}
Note for next: {1-line context for next iteration}
```

This context helps Claude understand patterns and avoid repeating mistakes across iterations.

### Lock File Management

The run command uses a lock file (`.lock`) to prevent concurrent execution:

- **Active Lock** - If a loop is already running, the command exits with an error showing the process ID
- **Stale Lock** - If the process is no longer running, the stale lock is automatically removed
- **Manual Removal** - If needed, manually remove: `rm ralph/loops/<name>/.lock`

### Related Commands

- `ralph create <name>` - Create a new automation loop
- `ralph status <name>` - Monitor loop execution in real-time
- `ralph show <name>` - Display loop configuration and progress
- `ralph list` - List all loops
- `ralph archive <name>` - Archive completed loop

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph

**Error: "Loop does not exist"**
- Run `ralph list` to see available loops
- Create loop with `ralph create <name>`

**Error: "Cannot run archived loops"**
- Unarchive first: `ralph unarchive <name>`
- Or create a new loop with the same configuration

**Error: "Loop is already running"**
- Another process is executing the loop
- Wait for it to complete or terminate the process
- If it's a stale lock, remove manually: `rm ralph/loops/<name>/.lock`

**Error: "Branch does not exist"**
- The loop configuration references a non-existent branch
- Create branch manually: `git checkout -b <branch-name>`
- Or update `config.json` to reference correct branch

**Error: "Failed to checkout branch"**
- Uncommitted changes prevent branch checkout
- Commit or stash changes: `git stash`
- Resolve merge conflicts if any exist

**Quality gates failing**
- Fix the issues reported by the quality gate
- Run quality gate manually to verify: `npm run lint`, `npm run build`
- Adjust quality gate configuration in `ralph/config.yaml` if needed
- Disable specific gates in loop's `config.json` if not applicable

**Loop gets stuck on a story**
- Review `progress.txt` for patterns or errors
- Check story acceptance criteria in `docs/sprint-status.yaml`
- Manually fix issues and resume: `ralph run <name>`
- Use `--restart` to start fresh if needed
- Consider increasing `stuck_threshold` in `config.json`

**No stories being processed**
- Verify `docs/sprint-status.yaml` has stories with status "not-started" or "in-progress"
- Check epic filter in `config.json` if stories are being filtered out
- Run `ralph show <name>` to see loop configuration

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/run.sh`. The core orchestration logic is in `loop.sh` which is generated per-loop by the `ralph create` command.

The run command handles:
- Validation and safety checks (lock files, branch management)
- Dry run mode for simulation
- Delegation to `loop.sh` for actual story execution

The loop.sh script (generated per loop) handles:
- Reading and interpreting `docs/sprint-status.yaml`
- Invoking Claude Code CLI with the loop's `prompt.md` context
- Quality gate execution and validation
- Progress tracking and statistics updates
- Commit creation and status updates

This separation allows for loop-specific configurations while maintaining consistent execution patterns.
