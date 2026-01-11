You are executing the **Ralph Delete** command to remove a loop.

## Command Overview

**Purpose:** Permanently delete a loop and all its files (configuration, progress, history)

**Agent:** Ralph CLI

**Output:** Loop directory removed from `ralph/loops/<name>/`

---

## Execution

Run the ralph CLI delete command with the loop name:

```bash
ralph delete <loop-name>
```

### Required Arguments

- `<loop-name>` - Name of the loop to delete (must be an active loop)

### Options

- `--force` - Skip confirmation prompt and delete immediately

### Examples

```bash
# Delete with confirmation prompt
ralph delete failed-experiment

# Delete without confirmation (dangerous!)
ralph delete old-loop --force

# Quick cleanup of test loop
ralph delete test-config --force
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Validates loop exists in `ralph/loops/`
   - Prevents deletion of archived loops (read-only for historical record)

2. **Prompts for Confirmation (unless --force)**
   - Shows warning about permanent deletion
   - Lists what will be deleted (all loop files)
   - Notes that git branch will NOT be deleted
   - Provides command to manually delete branch if desired
   - Requires explicit 'y' or 'Y' to proceed

3. **Deletes Loop Directory**
   - Recursively removes `ralph/loops/<loop-name>/`
   - Deletes all files: `config.json`, `progress.txt`, `loop.sh`, `prompt.md`
   - Removes all execution history and tracking data
   - Operation is permanent and cannot be undone

4. **Preserves Git Branch**
   - Git branch `ralph/<loop-name>` is NOT deleted
   - Shows warning with manual deletion command
   - Preserves branch for safety (commits may be valuable)
   - User must explicitly delete branch if desired

5. **Confirms Success**
   - Shows success message confirming deletion
   - Reminds user about preserved git branch
   - Provides exact command to delete branch: `git branch -d <branch-name>`

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loop must exist as an active loop in `ralph/loops/`
- Loop must not be archived (unarchive first if needed)

### Archived Loops

**Important:** Archived loops cannot be deleted directly. This is by design for data integrity.

Archived loops are in `ralph/archive/` and serve as historical record:
- They preserve feedback and completion data
- They document what worked (or didn't work)
- They provide reference for future loops

If you need to remove an archived loop:
1. Consider: Do you really need to delete history?
2. Alternative: Keep the archive for future reference
3. Last resort: Manually remove from `ralph/archive/` (not recommended)

To reuse an archived loop:
- Use `ralph unarchive <name>` to restore it to active loops
- Use `ralph clone <archived-name> <new-name>` to create fresh copy

### Git Branch Handling

The delete command does NOT delete git branches. This is intentional:

**Why branches are preserved:**
- Branches may contain commits you want to keep
- Branch deletion can be dangerous if commits aren't merged
- Users should explicitly decide on branch cleanup
- Easy to delete branch later, hard to recover commits

**To delete the git branch after loop deletion:**

```bash
# Safe delete (only if fully merged)
git branch -d ralph/<loop-name>

# Force delete (even if not merged - DANGEROUS!)
git branch -D ralph/<loop-name>
```

**Best practice:** Review branch commits before deleting:
```bash
git log ralph/<loop-name>
```

### Related Commands

- `ralph archive <name>` - Archive loop instead of deleting (preserves history)
- `ralph list` - See all available loops
- `ralph show <name>` - View loop details before deleting
- `ralph unarchive <name>` - Restore archived loop before deletion

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph
- Creates the `ralph/` directory structure

**Error: "Loop name is required"**
- You must provide a loop name: `ralph delete <loop-name>`
- Run `ralph list` to see available loops

**Error: "Loop does not exist"**
- Loop name may be misspelled
- Run `ralph list` to see available loops
- Loop may already be deleted
- Loop may be in archive (see archived loops section)

**Error: "Cannot delete archived loops"**
- Archived loops are read-only for historical record
- To remove: unarchive first, then delete (or manually remove from archive/)
- Consider: Do you really need to delete history?
- Alternative: Use `ralph clone` to reuse configuration without affecting archive

**Deletion cancelled after confirmation prompt**
- This is normal - you answered 'n' or 'N' to the confirmation
- Loop is safe and unchanged
- To proceed with deletion, run command again and answer 'y' or 'Y'
- Or use `--force` flag to skip prompt

**Error: "Failed to delete loop"**
- Check file permissions for `ralph/loops/` directory
- Loop directory may be open in editor or terminal
- Close any open files from the loop
- Check disk is not full or read-only
- Verify you have write permissions

**Branch deletion fails**
- Use `git branch -D <branch>` for force delete
- Branch may be currently checked out (checkout different branch first)
- Branch may not exist (already deleted or never created)
- Check branch name: `git branch -a | grep ralph`

**Accidentally deleted loop**
- Check git history: loop files may be in git
- Restore from backup if available
- Check `.git/objects` for recent commits
- Last resort: Recreate from scratch with `ralph create`

**Want to delete but keep history**
- Use `ralph archive <name>` instead of delete
- Archive preserves all history and feedback
- Archived loops can be cloned for reuse
- Archived loops can be unarchived to continue work

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/delete.sh`.

The delete command provides a safe way to remove loops you no longer need:

**Key Features:**

1. **Safety-First Design**
   - Confirmation prompt by default
   - Clear warning about permanent deletion
   - Prevents accidental archived loop deletion
   - Preserves git branches (commits may be valuable)
   - All-or-nothing operation (complete success or failure)

2. **Archived Loop Protection**
   - Cannot delete archived loops directly
   - Forces explicit decision about historical data
   - Encourages preservation of completed work
   - Prevents accidental loss of feedback data
   - Clear error message with alternatives

3. **Git Branch Preservation**
   - Never automatically deletes branches
   - Shows clear warning about preserved branch
   - Provides exact command for manual deletion
   - Explains safe vs force delete options
   - Protects against accidental commit loss

4. **Clear User Feedback**
   - Explicit confirmation prompt shows what will be deleted
   - Success message confirms operation completed
   - Error messages explain what went wrong
   - Warnings include suggested next steps
   - Related commands shown in context

5. **Validation and Error Handling**
   - Validates Ralph is initialized
   - Validates loop exists and is active
   - Checks for archived loops separately
   - Clear error messages for all failure modes
   - Exit codes indicate success/failure

**Data Flow:**

1. User runs `ralph delete <loop-name> [--force]`
2. Command validates prerequisites (Ralph initialized, loop exists, not archived)
3. Command reads `config.json` to find git branch name
4. Without `--force`: Prompts for confirmation with warning
   - Shows loop name to be deleted
   - Notes that git branch will be preserved
   - Provides command to delete branch manually
   - Waits for user response (y/n)
5. With `--force` or after confirmation: Deletes loop directory
   - Recursively removes `ralph/loops/<loop-name>/`
   - All files permanently deleted
6. Shows success message
7. Reminds user about preserved git branch with deletion command

**Confirmation Prompt:**

The confirmation prompt shows:
```
This will permanently delete the loop '<loop-name>' and all its files

Note: Git branch 'ralph/<loop-name>' will NOT be deleted
      You can delete it manually with: git branch -d ralph/<loop-name>

Are you sure you want to delete this loop? [y/N]:
```

Key aspects:
- Default is NO (safe default)
- Shows exact loop name
- Warns about permanence
- Notes git branch preservation
- Provides manual deletion command
- Requires explicit 'y' or 'Y' to proceed

**Archive vs Delete:**

Understanding when to use each:

**Use Archive when:**
- Loop successfully completed work
- You want to preserve feedback/history
- You might want to reuse configuration later
- You want to document what was accomplished
- You want to track satisfaction/learnings

**Use Delete when:**
- Loop was created by mistake
- Loop is a failed experiment with no value
- Loop is a temporary test that served its purpose
- Loop contains no useful history or learnings
- You need to clean up clutter

**Best practice:** When in doubt, archive instead of delete. Disk space is cheap, but lost data is expensive.

**Force Flag Usage:**

The `--force` flag skips confirmation. Use with caution:

**Safe to use --force for:**
- Cleanup scripts that delete many test loops
- Deleting loops you just created by mistake
- CI/CD pipelines that create temporary loops
- Loops you're certain don't contain valuable data

**DO NOT use --force for:**
- Loops that ran successfully (archive instead)
- Loops that might have valuable commits
- Loops you're unsure about
- Production loops without backup
- Loops created by others without asking

**Deletion Process:**

The command uses `rm -rf` to recursively remove the loop directory:

```bash
rm -rf "ralph/loops/<loop-name>"
```

This means:
- ALL files in the directory are deleted
- ALL subdirectories are deleted
- Operation is IMMEDIATE and PERMANENT
- No trash/recycle bin (files gone forever)
- No undo or recovery mechanism

**Recovery Options:**

If you accidentally delete a loop:

1. **Check git history** - If loop files were committed:
   ```bash
   git log --all --full-history -- ralph/loops/<loop-name>/
   git checkout <commit-hash> -- ralph/loops/<loop-name>/
   ```

2. **Check backups** - If you have backups:
   - Time Machine (macOS)
   - File History (Windows)
   - System snapshots
   - Cloud sync services

3. **Recreate from scratch** - If no recovery possible:
   - Use `ralph create <name>` to create new loop
   - Review git branch for any valuable commits
   - Use `ralph show` on similar loops for reference

**Alternative Approaches:**

Before deleting, consider these alternatives:

1. **Archive:** Preserve history and feedback for future reference
2. **Clone then Delete:** Create backup before deletion
3. **Edit:** Modify loop configuration instead of starting over
4. **Pause:** Just stop running loop without deleting
5. **Rename:** Move files manually if you just need different name

**Use Cases:**

1. **Failed Experiments**
   ```bash
   ralph delete test-approach-1 --force
   ralph delete broken-config --force
   ```

2. **Cleanup After Migration**
   ```bash
   ralph delete old-implementation
   # After confirming new implementation works
   ```

3. **Remove Duplicates**
   ```bash
   ralph delete loop-name-copy
   ralph delete loop-name-backup
   ```

4. **CI/CD Cleanup**
   ```bash
   # In automated scripts
   ralph delete ci-test-loop --force
   ```

**Security Considerations:**

- Loop files may contain sensitive data (API keys, credentials, etc.)
- Deletion doesn't securely wipe data (may be recoverable with forensics)
- For sensitive loops: Consider secure deletion tools after `ralph delete`
- Git history may still contain loop commits (clean git history if needed)
- Archived loops may reference deleted loops (check references)

**Best Practices:**

1. **Archive Instead of Delete:** Default to archiving for valuable work
2. **Review Before Deleting:** Run `ralph show <name>` first
3. **Check Git Branch:** Review commits before deleting branch
4. **Use Confirmation:** Avoid `--force` unless certain
5. **Document Deletions:** Note in project docs what was deleted and why
6. **Clean Up Branches:** Delete git branch after loop deletion
7. **Verify After Deletion:** Run `ralph list` to confirm removal
8. **Backup Important Loops:** Before deletion, clone or archive as backup
