You are executing the **Ralph Unarchive** command to restore an archived loop.

## Command Overview

**Purpose:** Restore an archived loop back to active status for continued work or reuse

**Agent:** Ralph CLI

**Output:** Loop restored to `ralph/loops/<name>/` with optional statistics reset

---

## Execution

Run the ralph CLI unarchive command with archive name:

```bash
ralph unarchive <archive-name>
```

### Required Arguments

- `<archive-name>` - Name of the archived loop to restore (can omit date prefix)

### Options

- `--reset-stats` - Reset execution statistics to zero (fresh start)
- `--no-branch` - Skip git branch creation/checkout

### Examples

```bash
# Restore archived loop (with date prefix)
ralph unarchive 2026-01-10-sprint-1

# Restore using just the loop name (finds latest archive)
ralph unarchive sprint-1

# Restore with fresh statistics for rerunning
ralph unarchive auth-epic --reset-stats

# Restore without branch operations
ralph unarchive feature-config --no-branch

# Restore with both flags
ralph unarchive sprint-2 --reset-stats --no-branch
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Finds archived loop in `ralph/archive/`
   - Accepts full archive name or just loop name (finds date-prefixed directory)
   - Validates loop doesn't already exist in active loops
   - Validates config.json exists in archived loop

2. **Restores Loop to Active**
   - Moves entire loop directory from `ralph/archive/` to `ralph/loops/`
   - Removes date prefix from directory name
   - Preserves all files: config.json, progress.txt, loop.sh, prompt.md
   - Preserves feedback.json for historical reference

3. **Updates Loop Metadata**
   - Removes `archivedAt` timestamp from config.json
   - Uses atomic write for safety (temp file + validate + move)
   - Optionally resets execution statistics (with `--reset-stats`)

4. **Resets Statistics** (if `--reset-stats` flag)
   - Sets `iterationsRun` to 0
   - Sets `storiesCompleted` to 0
   - Clears `startedAt` and `completedAt` timestamps
   - Resets `averageIterationsPerStory` to 0
   - Clears `storyAttempts` object
   - Clears `storyNotes` object
   - Preserves configuration settings (quality gates, thresholds, custom instructions)

5. **Creates Git Branch** (unless `--no-branch` flag)
   - Extracts branch name from config.json or generates `ralph/<name>`
   - Checks if branch already exists
   - If branch exists: prompts to checkout existing branch
   - If branch doesn't exist: prompts to create and checkout new branch
   - Interactive prompts allow accepting with Enter or declining with 'n'
   - Handles uncommitted changes gracefully

6. **Confirms Success**
   - Shows success message with loop location
   - Notes if feedback.json was preserved
   - Shows branch operation results
   - Suggests next steps (show, run, edit)

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loop must exist in archive (`ralph/archive/`)
- Archive can be specified with or without date prefix
- Loop must not exist in active loops (prevents overwriting)
- `jq` must be installed for JSON manipulation
- Git repository recommended (for branch operations, optional)

### Understanding Archive Names

Archived loops have date-prefixed directory names:

**Format:** `YYYY-MM-DD-<loop-name>`

**Examples:**
- `2026-01-10-sprint-1`
- `2025-12-15-auth-epic`
- `2026-01-01-experiment`

**You can specify either:**
- Full archive name: `ralph unarchive 2026-01-10-sprint-1`
- Just the loop name: `ralph unarchive sprint-1` (finds `*-sprint-1`)

If multiple archives exist with the same loop name, the first match (alphabetically) is used.

### Statistics Reset Behavior

**Without `--reset-stats`:**
- Execution statistics are preserved from archived state
- `iterationsRun` reflects past work
- `storiesCompleted` shows previous progress
- `storyAttempts` and `storyNotes` preserved
- Useful for: investigating issues, resuming incomplete work

**With `--reset-stats`:**
- All execution statistics reset to zero
- Loop starts fresh as if never run
- Configuration preserved (quality gates, thresholds, etc.)
- Previous feedback preserved in feedback.json
- Useful for: rerunning loop with same config, fresh sprint

### Git Branch Handling

**Without `--no-branch` (default):**
- Checks if repository is a git repo
- Extracts branch name from config.json `branchName` field
- Falls back to `ralph/<loop-name>` if not specified
- Interactive prompts for branch operations:
  - **Branch exists:** Prompt to checkout existing branch
  - **Branch doesn't exist:** Prompt to create new branch
- Handles uncommitted changes (prompts to commit/stash)

**With `--no-branch`:**
- Skips all git operations
- Useful for: non-git projects, manual branch management, CI/CD

### Feedback Preservation

The archived loop may contain `feedback.json` from when it was archived:

```json
{
  "loopName": "sprint-1",
  "timestamp": "2026-01-10T15:30:00Z",
  "responses": {
    "overallSatisfaction": 4,
    "manualInterventions": 2,
    "workedWell": "Quality gates effective",
    "shouldImprove": "Stuck detection sensitivity",
    "runAgain": "yes"
  },
  "loopStats": {
    "storiesCompleted": 10,
    "totalStories": 12,
    "iterationsRun": 15
  }
}
```

**After Unarchive:**
- feedback.json is preserved in the restored loop directory
- Provides historical context for the loop's past execution
- Referenced by `ralph show <name>` command
- Not deleted if `--reset-stats` is used (historical record)

### Related Commands

- `ralph archive <name>` - Archive a completed loop
- `ralph list --archived` - List all archived loops with dates
- `ralph show <name>` - View loop details and feedback (works with archived or active)
- `ralph clone <archive-name> <new-name>` - Alternative: clone instead of unarchive
- `ralph edit <name>` - Edit restored loop configuration
- `ralph run <name>` - Run the restored loop

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph
- Creates the `ralph/` directory structure

**Error: "Archived loop '<name>' not found"**
- Run `ralph list --archived` to see available archived loops
- Archive name may be misspelled
- Try using full archive name with date prefix: `YYYY-MM-DD-<name>`
- Check archive directory: `ls ralph/archive/`

**Error: "Loop '<name>' already exists in active loops"**
- An active loop with this name already exists
- Options:
  - Delete active loop first: `ralph delete <name>`
  - Archive active loop first: `ralph archive <name>`
  - Use `ralph clone` instead to create with different name
  - Manually rename one of the loops

**Error: "Loop configuration file not found"**
- Archive directory is incomplete or corrupted
- config.json is missing from archived loop
- Archive may have been manually modified
- May need to restore from backup

**Warning: "Failed to update config.json"**
- Loop was restored but metadata update failed
- config.json may still have `archivedAt` timestamp
- Stats may not be reset even if `--reset-stats` provided
- Check file permissions and disk space
- Can manually edit config.json if needed

**Warning: "Not in a git repository - skipping branch creation"**
- Current directory is not a git repository
- Git branch operations will be skipped automatically
- Loop still restored successfully
- Use `git init` if you want git integration

**Warning: "Failed to create branch"**
- Git branch creation failed
- Common causes:
  - Uncommitted changes in working directory
  - Branch name conflicts
  - Detached HEAD state
  - Insufficient git permissions
- Loop still restored successfully
- Can manually create branch: `git checkout -b ralph/<name>`

**Prompt: "Do you want to checkout this existing branch?"**
- Branch `ralph/<name>` already exists in repository
- Answering 'Y' or pressing Enter: checks out existing branch
- Answering 'n': skips checkout, stays on current branch
- Checkout may fail if uncommitted changes exist
- Use `git stash` to temporarily save changes

**Prompt: "Create and checkout new branch?"**
- Branch `ralph/<name>` doesn't exist yet
- Answering 'Y' or pressing Enter: creates and checks out new branch
- Answering 'n': skips branch creation, stays on current branch
- Useful for isolating loop work in separate branch

**Permission denied errors**
- Check write permissions on `ralph/loops/` directory
- Check read permissions on archive directory
- May need to run with appropriate permissions
- Check if loop directory is locked by another process

**Multiple archives with same loop name**
- If multiple archives exist (e.g., `2026-01-01-sprint-1` and `2026-01-10-sprint-1`)
- Specifying just `sprint-1` uses first alphabetical match
- Use full archive name for specific archive
- Consider renaming archives if disambiguation needed

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/unarchive.sh`.

The unarchive command provides a safe and flexible way to restore archived loops:

**Key Features:**

1. **Flexible Archive Name Matching**
   - Accepts full archive name: `2026-01-10-sprint-1`
   - Accepts just loop name: `sprint-1` (finds `*-sprint-1`)
   - Uses pattern matching to find date-prefixed directories
   - First alphabetical match used if multiple archives exist
   - Simplifies command usage while maintaining precision

2. **Safe Move Operation**
   - Validates loop doesn't already exist in active loops
   - Atomic metadata updates (temp file + validate + move)
   - Move operation is all-or-nothing
   - Preserves all loop files and history
   - Removes date prefix from directory name

3. **Optional Statistics Reset**
   - `--reset-stats` flag provides fresh start capability
   - Preserves loop configuration (quality gates, thresholds)
   - Clears all execution state (iterations, attempts, notes)
   - Useful for rerunning same configuration
   - Feedback.json preserved even with reset (historical record)

4. **Interactive Git Integration**
   - Detects if repository is git-enabled
   - Prompts for branch operations (non-intrusive)
   - Handles existing branches gracefully
   - Provides clear feedback on branch operations
   - `--no-branch` flag for non-interactive use

5. **Historical Data Preservation**
   - feedback.json preserved from archive
   - Provides context on past execution
   - Referenced by show command for historical view
   - Never deleted, even with `--reset-stats`
   - Valuable for learning and improvement

**Data Flow:**

1. User runs `ralph unarchive <name> [--reset-stats] [--no-branch]`
2. Command validates prerequisites (Ralph init)
3. Finds archived loop (with or without date prefix)
4. Validates destination doesn't exist in active loops
5. Validates config.json exists in archived loop
6. Creates `ralph/loops/` directory if needed
7. Moves loop: `mv ralph/archive/<archive-name> ralph/loops/<loop-name>`
8. Removes `archivedAt` timestamp from config.json
9. If `--reset-stats`: resets execution statistics in config.json
10. Saves updated config.json (atomic write)
11. Notes if feedback.json exists in restored loop
12. If not `--no-branch`: prompts for git branch operations
13. Shows success message and next steps

**Atomic Write Pattern:**

Config.json updates use atomic writes for safety:

```bash
# Remove archivedAt and optionally reset stats
jq 'del(.archivedAt)' config.json > temp_file

# Optionally reset stats
if [[ "$reset_stats" == "true" ]]; then
  jq '.stats.iterationsRun = 0 | .stats.storiesCompleted = 0 | ...' temp_file > temp_file2
  mv temp_file2 temp_file
fi

# Atomic move
mv temp_file config.json
```

This ensures:
- Invalid JSON never overwrites files
- Updates are atomic (all-or-nothing)
- Failures detected before damage occurs

**Config.json Metadata Changes:**

**Removed:**
- `archivedAt` timestamp (loop no longer archived)

**Optionally Reset (with --reset-stats):**
- `stats.iterationsRun` → 0
- `stats.storiesCompleted` → 0
- `stats.startedAt` → null
- `stats.completedAt` → null
- `stats.averageIterationsPerStory` → 0
- `storyAttempts` → {}
- `storyNotes` → {}

**Always Preserved:**
- `project`, `loopName`, `branchName`, `description`
- `config` (quality gates, thresholds, custom instructions)
- `generatedAt`, `sprintStatusPath`, `epicFilter`

**Git Branch Operations:**

Branch name is determined by:
1. Reading `branchName` from config.json
2. Falling back to `ralph/<loop-name>` if not specified

Branch operations are interactive:
```bash
# Check if branch exists
if git_branch_exists "$branch_name"; then
  # Prompt to checkout existing branch
  echo -n "Do you want to checkout this existing branch? [Y/n] "
  read -r response
  # ...
else
  # Prompt to create new branch
  echo -n "Create and checkout new branch? [Y/n] "
  read -r response
  # ...
fi
```

This provides:
- Non-destructive defaults (prompts before changes)
- Clear user control over git operations
- Graceful handling of uncommitted changes
- Skipped entirely with `--no-branch` flag

**Use Cases:**

1. **Resume Incomplete Work**
   - Unarchive without `--reset-stats`
   - Preserves execution state and progress
   - Continue where loop left off
   - Review feedback.json for context

2. **Rerun Successful Configuration**
   - Unarchive with `--reset-stats`
   - Preserves quality gates and settings
   - Fresh execution state for new work
   - Reference feedback.json for what worked well

3. **Investigate Past Issues**
   - Unarchive without `--reset-stats`
   - Review progress.txt for execution history
   - Check feedback.json for reported problems
   - Debug with preserved state

4. **Clone Alternative**
   - Unarchive provides in-place restoration
   - Clone creates copy with new name
   - Use unarchive if you want original loop name
   - Use clone if you want both loops active

**Best Practices:**

1. **Check Archives First:** Run `ralph list --archived` to see available loops
2. **Use Full Name for Precision:** Use full archive name if multiple exist
3. **Reset for Reruns:** Use `--reset-stats` when rerunning configuration
4. **Preserve for Investigation:** Don't use `--reset-stats` when investigating
5. **Review Feedback:** Check feedback.json for context before running
6. **Create Branches:** Let command create git branches for isolation
7. **Manual Cleanup:** Delete or re-archive loops when done to keep workspace clean
8. **Prefer Clone for Reuse:** Use `ralph clone` if you want to keep archive

**Differences from Clone:**

| Operation | Unarchive | Clone |
|-----------|-----------|-------|
| Source remains | ❌ Moved from archive | ✅ Copied, source preserved |
| Destination name | ⚠️ Must match original | ✅ Any name you choose |
| Statistics | ⚠️ Optional reset | ✅ Always reset |
| feedback.json | ✅ Preserved | ❌ Not copied |
| Use case | Restore for continued work | Reuse config for new work |

**When to Use Each:**
- **Unarchive:** Resume work, investigate issues, temporarily restore
- **Clone:** Reuse successful config, create similar loops, keep archive intact

**Integration with Other Commands:**

- `ralph list --archived`: Displays available archives with dates
- `ralph archive <name>`: Re-archive loop after unarchive
- `ralph show <name>`: View restored loop details and feedback
- `ralph run <name>`: Execute restored loop
- `ralph edit <name>`: Modify restored loop configuration
- `ralph clone <archive> <new>`: Alternative to unarchive for creating new loops
- `ralph delete <name>`: Remove restored loop (prompts for confirmation)

**Interactive vs Non-Interactive Use:**

**Interactive (default):**
- Prompts for git branch operations
- Allows user control over branch creation/checkout
- Shows detailed progress and confirmations
- Best for manual restoration by developers

**Non-Interactive (with --no-branch):**
- No prompts for branch operations
- Suitable for CI/CD pipelines
- Suitable for scripts and automation
- Combine with `--reset-stats` for fresh automated runs

Example non-interactive usage:
```bash
ralph unarchive sprint-1 --reset-stats --no-branch
```

**Error Recovery:**

If unarchive fails partway through:
- Loop directory may be partially moved
- Check both `ralph/archive/` and `ralph/loops/` for loop directory
- Manually complete move if needed: `mv ralph/archive/<name> ralph/loops/<name>`
- Manually edit config.json to remove `archivedAt` if needed
- Atomic writes prevent corrupt JSON files

**Security Considerations:**

1. **Preserved Feedback:** feedback.json may contain sensitive information about issues
2. **Historical Data:** Progress.txt may reference production issues or credentials
3. **Branch Names:** May reveal project structure or sensitive feature names
4. **Review Before Sharing:** Check restored loops before committing to shared repositories
