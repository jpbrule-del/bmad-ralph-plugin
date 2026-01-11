You are executing the **Ralph Clone** command to copy a loop configuration.

## Command Overview

**Purpose:** Clone an existing loop to create a new loop with reset statistics and fresh execution state

**Agent:** Ralph CLI

**Output:** New loop at `ralph/loops/<destination>/` with optional git branch creation

---

## Execution

Run the ralph CLI clone command with source and destination loop names:

```bash
ralph clone <source> <destination>
```

### Required Arguments

- `<source>` - Name of the loop to clone (can be active or archived)
- `<destination>` - Name for the new loop (must not already exist)

### Options

This command has no flags or options. Git branch creation is handled via interactive prompt.

### Examples

```bash
# Clone a successful configuration for reuse
ralph clone sprint-1 sprint-2

# Clone from archived loop
ralph clone 2026-01-10-auth-feature new-auth-feature

# Clone for experimentation
ralph clone working-config experiment-config
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Validates source loop exists (checks both `ralph/loops/` and `ralph/archive/`)
   - Validates destination loop doesn't already exist
   - Validates destination name format (alphanumeric + hyphens)

2. **Copies All Loop Files**
   - Recursively copies entire source loop directory to destination
   - Includes `config.json`, `progress.txt`, `loop.sh`, `prompt.md`
   - Preserves all configuration settings (quality gates, thresholds, custom instructions)

3. **Resets Execution Statistics**
   - Updates `config.json` with new loop name
   - Resets `iterationsRun` to 0
   - Resets `storiesCompleted` to 0
   - Clears `startedAt` and `completedAt` timestamps
   - Clears `storyAttempts` and `storyNotes` objects
   - Generates new `generatedAt` timestamp

4. **Resets Progress Log**
   - Creates fresh `progress.txt` with new header
   - Includes "Cloned from: <source>" annotation
   - Preserves empty template structure for new iteration logs

5. **Optional Git Branch Creation**
   - Interactively prompts to create branch `ralph/<destination>`
   - If branch exists, offers to check it out
   - Updates `branchName` in `config.json` if branch created/checked out
   - Can skip branch creation if not needed

6. **Confirms Success**
   - Shows success message with next steps
   - Suggests reviewing configuration with `ralph show`
   - Suggests starting execution with `ralph run`

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Source loop must exist (active or archived)
- Destination loop must not exist
- `jq` must be installed for JSON manipulation
- Git repository initialized (for branch creation)

### Destination Loop Name Rules

Loop names must follow these rules:
- Contain only alphanumeric characters and hyphens
- Start with a letter or number (not a hyphen)
- Not end with a hyphen
- Cannot be empty

**Valid examples:**
- `sprint-2`
- `feature-auth`
- `epic001`
- `test-config`

**Invalid examples:**
- `-invalid` (starts with hyphen)
- `invalid-` (ends with hyphen)
- `invalid space` (contains space)
- `invalid_underscore` (contains underscore)

### Cloning from Archived Loops

You can clone from archived loops:
- Archived loops are in `ralph/archive/` with format `YYYY-MM-DD-<name>`
- Use the loop name without the date prefix
- Example: `ralph clone auth-feature new-auth` works for `ralph/archive/2026-01-10-auth-feature/`
- This is useful for reusing successful configurations from past work

### What Gets Preserved

The clone preserves:
- Quality gate configuration
- Max iterations setting
- Stuck threshold
- Custom instructions
- Epic filter (if set)
- Prompt template
- Loop script logic

### What Gets Reset

The clone resets:
- Execution statistics (iterations, stories completed)
- Story attempts tracking
- Story notes/history
- Progress log entries
- Timestamps (startedAt, completedAt, generatedAt)

### Related Commands

- `ralph create <name>` - Create new loop from scratch
- `ralph list` - See available loops (both active and archived)
- `ralph show <name>` - View cloned loop configuration
- `ralph run <name>` - Start executing the cloned loop
- `ralph unarchive <name>` - Restore archived loop (alternative to cloning)

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph
- Creates the `ralph/` directory structure

**Error: "Source loop does not exist"**
- Run `ralph list` to see available loops (both active and archived)
- Source loop name may be misspelled
- For archived loops, use the name without date prefix

**Error: "Destination loop already exists"**
- Choose a different destination name
- Or delete existing loop with `ralph delete <destination>` first
- Or use `ralph run <destination>` if you meant to use existing loop

**Error: "Invalid destination loop name"**
- Loop names must contain only alphanumeric characters and hyphens
- Must start and end with alphanumeric characters
- Examples: `sprint-2`, `feature-auth`, `test-1`

**Error: "Failed to copy loop files"**
- Check disk space availability
- Verify source loop directory is intact
- Check file permissions for `ralph/loops/` directory

**Error: "Failed to update config.json"**
- Source loop's `config.json` may be corrupted
- Check with: `jq . ralph/loops/<source>/config.json`
- Fix source loop or create from scratch instead

**Warning: "config.json not found in source loop"**
- Source loop is incomplete or corrupted
- Clone will succeed but resulting loop may not work
- Consider creating new loop with `ralph create` instead

**Branch creation fails**
- Ensure git repository is initialized
- Branch may already exist (will prompt to check out)
- Can skip branch creation and create manually later

**Clone succeeds but loop doesn't run**
- Run `ralph show <destination>` to verify configuration
- Check quality gate commands are valid for current project
- Ensure sprint-status.yaml path is correct
- May need to edit config with `ralph edit <destination>`

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/clone.sh`.

The clone command provides an efficient way to reuse successful loop configurations for new work:

**Key Features:**

1. **Flexible Source Selection**
   - Clone from active loops in `ralph/loops/`
   - Clone from archived loops in `ralph/archive/`
   - Automatic archive date prefix handling
   - Clear feedback when cloning from archive

2. **Complete State Reset**
   - All execution state cleared for fresh start
   - Configuration preserved for consistency
   - New timestamps for accurate tracking
   - Empty progress log ready for new work

3. **Safe Destination Validation**
   - Prevents overwriting existing loops
   - Validates loop name format
   - Creates destination directory atomically
   - Cleans up on failure

4. **Interactive Git Integration**
   - Optional branch creation via prompt
   - Handles existing branch conflicts
   - Updates config.json with branch name
   - Can skip if branch not needed

5. **Atomic Operations**
   - Uses temporary files for JSON updates
   - Validates updated JSON before committing
   - Cleans up destination on any failure
   - All-or-nothing approach prevents partial clones

**Data Flow:**

1. User runs `ralph clone <source> <destination>`
2. Command validates prerequisites (Ralph initialized, source exists, destination available)
3. Command locates source loop (checks active loops, then archive)
4. Creates destination directory: `ralph/loops/<destination>/`
5. Copies all files: `cp -r source/* destination/`
6. Updates `config.json`:
   - Sets `loopName` to destination
   - Resets all stats to zero/null
   - Clears `storyAttempts` and `storyNotes`
   - Updates `generatedAt` timestamp
7. Updates `progress.txt`:
   - Creates fresh header with new loop name
   - Adds "Cloned from: <source>" annotation
   - Empty iteration log section
8. Prompts for git branch creation (interactive)
9. Shows success message with next steps

**Loop Discovery:**

The command searches for source loops in this order:
1. `ralph/loops/<source>` - Active loop with exact name
2. `ralph/archive/*-<source>` - Archived loop with date prefix (e.g., `2026-01-10-<source>`)

This allows cloning from both active and archived loops without requiring date prefix.

**JSON Update Process:**

The command uses atomic write pattern for safety:
```bash
jq '<transformations>' config.json > temp_file
jq . temp_file  # Validate JSON
mv temp_file config.json  # Atomic write
```

This ensures:
- Invalid JSON never overwrites the original
- Updates are atomic (all-or-nothing)
- Failures are detected before damage occurs

**Git Branch Handling:**

Branch creation is optional and interactive:
- Default: Prompt to create `ralph/<destination>` branch
- If branch exists: Prompt to check it out
- If already on branch: No action needed
- If declined: Skip branch creation, can create manually later

The `branchName` field in `config.json` is updated only if:
- New branch is created and checked out
- Existing branch is checked out
- Otherwise, keeps value from source loop

**Use Cases:**

1. **Reusing Successful Configurations**
   - Clone a loop that worked well
   - Use same quality gates, thresholds, prompts
   - Start fresh with new stories

2. **Creating Sprint Variations**
   - Clone `sprint-1` to `sprint-2`
   - Preserve quality gates and settings
   - Reset progress for new sprint

3. **Experimentation**
   - Clone production config to test variations
   - Try different quality gate combinations
   - Keep original config intact

4. **Restoring Archived Work**
   - Clone from archived loop instead of unarchive
   - Get fresh start with proven config
   - Preserve archived loop for history

**Differences from Unarchive:**

Clone vs Unarchive:
- **Clone:** Creates new loop, resets stats, source unchanged
- **Unarchive:** Moves archived loop back to active, preserves stats

Use clone when:
- You want to reuse configuration only
- You need fresh statistics
- You want to keep the archive intact

Use unarchive when:
- You want to resume archived work
- You need to preserve history
- You want to continue where you left off

**Best Practices:**

1. **Review After Cloning:** Run `ralph show <destination>` to verify configuration
2. **Edit as Needed:** Use `ralph edit <destination>` to adjust settings
3. **Descriptive Names:** Use meaningful destination names (e.g., `sprint-2`, not `test2`)
4. **Clean Up Sources:** Archive or delete old loops you're cloning from
5. **Branch Strategy:** Create git branches for better isolation
6. **Test Quality Gates:** Verify gates work before running cloned loop
7. **Document Clones:** Note in progress.txt why you cloned and what's different
