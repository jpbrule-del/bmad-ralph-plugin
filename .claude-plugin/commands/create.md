You are executing the **Ralph Create** command to create a new automation loop.

## Command Overview

**Purpose:** Create a new Ralph automation loop for executing BMAD sprint stories

**Agent:** Ralph CLI

**Output:** Loop directory in `ralph/loops/<name>` with configuration and orchestration files

---

## Execution

Run the ralph CLI create command with a loop name:

```bash
ralph create <loop-name>
```

### Required Arguments

- `<loop-name>` - Name for the loop (alphanumeric and hyphens only)
  - Must start with letter or number
  - Must not end with hyphen
  - Examples: `feature-auth`, `sprint-1`, `epic002`

### Options

- `--epic <id>` - Filter stories to only those in specified epic (e.g., `EPIC-001`)
- `--yes` - Use default configuration without interactive prompts
- `--no-branch` - Skip creating git branch `ralph/<name>`

### Examples

```bash
# Create loop for all pending stories (interactive)
ralph create my-sprint

# Create loop for specific epic with defaults
ralph create auth-epic --epic EPIC-001 --yes

# Create loop without git branch
ralph create quick-test --no-branch

# Create loop with all options
ralph create feature-impl --epic EPIC-002 --yes --no-branch
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/config.yaml` or `ralph/config.json` exists)
   - Validates loop name format
   - Checks loop doesn't already exist
   - Validates `docs/sprint-status.yaml` exists and is valid YAML

2. **Analyzes Sprint Status**
   - Reads `docs/sprint-status.yaml`
   - Finds all pending stories (status: "not-started" or "in-progress")
   - Filters by epic if `--epic` flag provided
   - Displays story count and preview of first 5 stories
   - Exits if no pending stories found

3. **Interactive Configuration** (unless `--yes`)
   - Prompts for epic filter if not specified
   - Prompts for max iterations (default: 50)
   - Prompts for stuck threshold (default: 3)
   - Prompts for quality gates configuration
   - Shows configuration summary and asks for confirmation
   - Updates `ralph/config.json` with quality gate settings

4. **Generates Loop Files**
   - **`loop.sh`** - Orchestration script for executing stories
     - Configured with max iterations and stuck threshold
     - Contains quality gate commands
     - Main executable for the loop
   - **`config.json`** - Loop configuration and tracking
     - Project metadata and settings
     - Story attempt tracking
     - Execution statistics
   - **`prompt.md`** - Context prompt for Claude
     - Loop instructions and rules
     - Quality gate requirements
     - Progress tracking format
   - **`progress.txt`** - Iteration log
     - Records each story attempt
     - Tracks learnings and patterns
     - Maintains execution history

5. **Creates Git Branch** (unless `--no-branch`)
   - Creates branch `ralph/<loop-name>`
   - Checks out new branch
   - Prompts to continue if branch already exists
   - Fails gracefully if git not available

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Must have valid `docs/sprint-status.yaml` with pending stories
- Git must be available (unless `--no-branch`)
- Required CLI tools: `jq` (>=1.6), `yq` (>=4.0)

### Story Filtering

The create command reads stories from `docs/sprint-status.yaml` and includes:

- Stories with status: `not-started` or `in-progress`
- Stories from all epics (default) or filtered epic (`--epic`)
- Stories ordered by epic and priority

**Epic Format:**
```yaml
epics:
  - id: "EPIC-001"
    name: "Plugin Foundation"
    stories:
      - id: "STORY-001"
        title: "Create Plugin Manifest"
        status: "not-started"
        points: 3
```

### Loop File Structure

After creation, loop directory contains:

```
ralph/loops/<loop-name>/
├── loop.sh         # Main orchestration script (executable)
├── config.json     # Configuration and tracking data
├── prompt.md       # Context for Claude agent
└── progress.txt    # Iteration log
```

### Interactive Prompts (without --yes)

When running without `--yes`, the command prompts for:

1. **Epic Filter**
   - Shows list of available epics
   - Option to select specific epic or "All Epics"

2. **Max Iterations**
   - Maximum story attempts before stopping
   - Default: 50
   - Prevents infinite loops

3. **Stuck Threshold**
   - Number of failed attempts before marking story as stuck
   - Default: 3
   - Triggers `<stuck>STORY_ID: reason</stuck>` output

4. **Quality Gates**
   - Typecheck command (e.g., `npx tsc --noEmit`)
   - Test command (e.g., `npm test`)
   - Lint command (e.g., `npm run lint`)
   - Build command (e.g., `npm run build`)
   - Auto-detected from `package.json` or manual entry

### Default Mode (--yes)

With `--yes` flag:
- Uses max_iterations: 50
- Uses stuck_threshold: 3
- Uses quality gates from `ralph/config.yaml` or `ralph/config.json`
- Uses epic filter from `--epic` flag or includes all epics
- No interactive prompts or confirmations

### Next Steps

After creating a loop:

1. **Review Configuration**
   ```bash
   ralph show <loop-name>
   # View loop configuration and story list
   ```

2. **Edit Configuration** (optional)
   ```bash
   ralph edit <loop-name>
   # Opens config.json in $EDITOR
   ```

3. **Run the Loop**
   ```bash
   ralph run <loop-name>
   # Starts autonomous story execution
   ```

4. **Monitor Progress**
   ```bash
   ralph status <loop-name>
   # Watch real-time execution
   ```

### Related Commands

- `ralph list` - List all loops
- `ralph show <name>` - View loop details
- `ralph edit <name>` - Edit loop configuration
- `ralph run <name>` - Execute the loop
- `ralph status <name>` - Monitor loop execution
- `ralph delete <name>` - Remove a loop
- `ralph clone <source> <dest>` - Copy loop configuration

### Troubleshooting

**Error: "Ralph is not initialized"**
- Run `ralph init` first to initialize Ralph in the project

**Error: "Loop already exists"**
- Choose a different loop name
- Or delete existing loop: `ralph delete <name>`
- Or use existing loop: `ralph run <name>`

**Error: "Epic not found"**
- Check epic ID spelling (e.g., `EPIC-001` not `epic-001`)
- List available epics in `docs/sprint-status.yaml`
- Ensure epic has `id` field

**Error: "No pending stories found"**
- Check `docs/sprint-status.yaml` for stories with status: `not-started` or `in-progress`
- Verify epic filter is correct if using `--epic`
- All stories may already be completed

**Error: "Invalid loop name"**
- Loop name must contain only alphanumeric and hyphens
- Must start with letter or number
- Must not end with hyphen
- Valid: `my-sprint`, `epic001`, `feature-auth`
- Invalid: `-test`, `my_sprint`, `test-`

**Git branch creation failed**
- Ensure git is initialized: `git init`
- Check if branch already exists: `git branch -a`
- Use `--no-branch` to skip branch creation
- Manually create branch later: `git checkout -b ralph/<name>`

**Quality gates configuration**
- Edit `ralph/config.yaml` or `ralph/config.json` to set defaults
- Use `ralph config quality-gates` for interactive configuration
- Leave fields empty to skip specific gates

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/create.sh`.

The command orchestrates multiple components:
- `sprint_analysis.sh` - Parses and validates sprint-status.yaml
- `interactive.sh` - Handles user prompts and input
- `git.sh` - Creates and manages git branches
- `loop_generator.sh` - Generates loop.sh orchestration script
- `prd_generator.sh` - Generates config.json configuration
- `prompt_generator.sh` - Generates prompt.md context file
- `progress_generator.sh` - Generates progress.txt log file

All validation, story filtering, file generation, and git operations are handled by the CLI, ensuring consistent behavior between CLI and plugin usage.
