You are executing the **Ralph Uninstall** command to completely remove Ralph from the system.

## Command Overview

**Purpose:** Remove all Ralph components including CLI, Claude Code skills, project data, and git branches

**Agent:** Ralph CLI

**Output:** List of components to remove, confirmation prompt, removal status

---

## Execution

Run the ralph CLI uninstall command:

```bash
ralph uninstall [--force] [--keep-projects] [--dry-run]
```

### Options

- `--force, -f` - Skip confirmation prompts
- `--keep-projects` - Don't remove project-level `ralph/` directories
- `--dry-run, -n` - Show what would be removed without removing

### Examples

```bash
# Preview what would be removed (safe)
ralph uninstall --dry-run

# Uninstall with confirmation prompt
ralph uninstall

# Uninstall but keep project data
ralph uninstall --keep-projects

# Uninstall without prompts (for scripting)
ralph uninstall --force

# Uninstall keeping project data, no prompts
ralph uninstall --force --keep-projects
```

### What It Removes

1. **Claude Code Skills** (`~/.claude/commands/ralph/`)
   - All skill markdown files
   - Makes `/ralph:*` commands unavailable in Claude Code CLI
   - Files and size shown before removal

2. **Global CLI**
   - Unlinks `ralph` command from npm
   - Removes global accessibility from terminal
   - Path shown before removal

3. **Current Project ralph/ Directory** (unless `--keep-projects`)
   - Removes `ralph/` directory in current working directory
   - Includes loops, archives, and configuration
   - Files count and size shown before removal

4. **Git Branches** (`ralph/*`)
   - Deletes all branches matching `ralph/*` pattern
   - Switches to main/master if currently on ralph branch
   - Lists branches before removal

5. **Source Directory** (manual only)
   - Shows location of ralph source
   - NOT automatically removed
   - Provides manual removal command

### Prerequisites

- Ralph must be installed
- Write permissions to `~/.claude/commands/`
- Git access for branch deletion (if applicable)

### Output Examples

**Dry Run:**

```
========================================
   Ralph Uninstall
========================================

DRY RUN - No changes will be made

  [1] Claude Code skills
      Path: /Users/you/.claude/commands/ralph
      Files: 14 (56K)

  [2] Global CLI
      Path: /usr/local/bin/ralph

  [3] Current project ralph/ directory
      Path: /Users/you/myproject/ralph
      Files: 127 (2.4M)

  [4] Git branches (ralph/*)
      - ralph/plugin-sprint
      - ralph/api-refactor

  [5] Ralph source directory
      Path: /Users/you/Desktop/ralph
      Size: 15M
      NOTE: This directory will NOT be removed automatically.
      Remove manually with: rm -rf /Users/you/Desktop/ralph

DRY RUN complete. No changes were made.

To perform the uninstall, run: ralph uninstall
```

**Confirmation Prompt:**

```
========================================
   Ralph Uninstall
========================================

  [1] Claude Code skills
      Path: /Users/you/.claude/commands/ralph
      Files: 14 (56K)

  [2] Global CLI
      Path: /usr/local/bin/ralph

  [3] Current project ralph/ directory
      Path: /Users/you/myproject/ralph
      Files: 127 (2.4M)

WARNING: This action is irreversible!

Are you sure you want to uninstall ralph? (type 'yes' to confirm):
```

**Successful Uninstall:**

```
Removing Ralph Components

[INFO] Removing Claude Code skills...
[OK] Removed: /Users/you/.claude/commands/ralph
[INFO] Unlinking global CLI...
[OK] Unlinked CLI from npm
[INFO] Removing project ralph/ directory...
[OK] Removed: /Users/you/myproject/ralph
[INFO] Deleting ralph/* git branches...
[OK] Deleted branch: ralph/plugin-sprint
[OK] Deleted branch: ralph/api-refactor

========================================
   Uninstall Complete!
========================================

  Ralph has been removed from your system.

  To completely remove ralph, also delete the source:
    rm -rf /Users/you/Desktop/ralph

  To reinstall later:
    git clone https://github.com/snarktank/ralph.git
    cd ralph && ./install.sh
```

**With --keep-projects:**

```
========================================
   Ralph Uninstall
========================================

  [1] Claude Code skills
      Path: /Users/you/.claude/commands/ralph
      Files: 14 (56K)

  [2] Global CLI
      Path: /usr/local/bin/ralph

  [3] Project directories: SKIPPED (--keep-projects)

  [4] Git branches (ralph/*)
      - ralph/plugin-sprint
```

**Nothing to Uninstall:**

```
========================================
   Ralph Uninstall
========================================

  Nothing to uninstall.
```

### Related Commands

- `ralph update` - Update to latest version
- `ralph list` - View all loops before uninstalling
- `ralph archive <name>` - Archive loops before uninstalling

### Troubleshooting

**Error: "npm unlink failed"**
- CLI may already be removed
- Try manual removal: `npm unlink -g @ralph/cli`
- Check npm permissions

**Error: "Failed to remove"**
- Check file/directory permissions
- Try with sudo: `sudo rm -rf ~/.claude/commands/ralph`
- Close any applications using the files

**Error: "Could not delete branch"**
- Branch may be currently checked out
- Switch to another branch first: `git checkout main`
- Try manual deletion: `git branch -D ralph/<name>`

**Error: "Could not switch from ralph branch"**
- main/master branch may not exist
- Create or checkout another branch first
- Try: `git checkout -b temp && git branch -D ralph/<name>`

**Project ralph/ directory not removed**
- May not be in the correct directory
- Check current directory: `pwd`
- Navigate to project root before running

**Skills still showing in Claude Code**
- Restart Claude Code CLI
- Check if files still exist: `ls ~/.claude/commands/ralph/`
- Manually remove: `rm -rf ~/.claude/commands/ralph/`

**Want to reinstall?**
- Clone repository: `git clone https://github.com/snarktank/ralph.git`
- Run installer: `cd ralph && ./install.sh`
- Or install via npm: `npm install -g @ralph/cli`

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/uninstall.sh`.

The uninstall command provides safe, comprehensive removal of Ralph:

**Key Features:**

1. **Safe Preview Mode**
   - `--dry-run` shows exactly what will be removed
   - Lists files, sizes, and paths
   - No changes made until confirmed

2. **Confirmation Protection**
   - Requires typing 'yes' to confirm
   - Prevents accidental data loss
   - Override with `--force` for scripting

3. **Selective Removal**
   - `--keep-projects` preserves project data
   - Useful when upgrading or switching machines
   - Loops and archives retained

4. **Comprehensive Cleanup**
   - Removes all CLI components
   - Cleans up Claude Code integration
   - Deletes related git branches

**Component Detection:**

The command detects installed components by:
- Skills: Checks `~/.claude/commands/ralph/` exists
- CLI: Uses `which ralph` to find installation
- Project: Looks for `ralph/` in current directory
- Branches: Lists branches matching `ralph/*` pattern
- Source: Resolves symlinks to find installation root

**Removal Order:**

1. Skills (least destructive first)
2. CLI global link
3. Project directory (if not skipped)
4. Git branches
5. Source (manual - not auto-removed)

**Safety Measures:**

- Source directory NOT automatically removed
- Explicit user confirmation required
- Clear display of what will be deleted
- Individual error handling per component
- Continues even if some removals fail

**Git Branch Handling:**

When on a ralph/* branch:
1. Attempts to switch to main
2. Falls back to master
3. Warns if switch fails
4. Deletes all ralph/* branches

**Exit Codes:**

- 0: Successful uninstall (or nothing to uninstall)
- 0: Cancelled by user
- 1: Errors during removal (partial uninstall)
