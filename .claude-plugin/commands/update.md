You are executing the **Ralph Update** command to pull and install the latest version.

## Command Overview

**Purpose:** Update Ralph CLI from git remote, pulling latest changes and reinstalling CLI and Claude Code skills

**Agent:** Ralph CLI

**Output:** Version comparison, update status, success/failure messages

---

## Execution

Run the ralph CLI update command:

```bash
ralph update [--check] [--force] [--skip-skills]
```

### Options

- `--check, -c` - Check for updates without installing
- `--force, -f` - Update even with uncommitted local changes (resets to remote)
- `--skip-skills` - Skip reinstalling Claude Code skills after update

### Examples

```bash
# Check for available updates
ralph update --check

# Update to latest version
ralph update

# Update with force (discards local changes)
ralph update --force

# Update without reinstalling skills
ralph update --skip-skills
```

### What It Does

1. **Validates Installation**
   - Checks ralph is installed from git repository
   - Verifies `.git` directory exists
   - Confirms network connectivity to remote

2. **Checks for Uncommitted Changes**
   - Detects local modifications in ralph directory
   - Fails unless `--force` is used
   - Warns user with options to commit, stash, or force

3. **Fetches from Remote**
   - Fetches latest commits from origin
   - Determines remote branch (main or master)
   - Compares local and remote versions

4. **Version Comparison**
   - Gets current version from `packages/cli/package.json`
   - Gets remote version from fetched remote
   - Compares commit hashes to detect changes

5. **Pulls Latest Changes**
   - Normal mode: `git pull origin <branch>`
   - Force mode: `git reset --hard origin/<branch>`
   - Handles merge conflicts gracefully

6. **Reinstalls Dependencies**
   - Runs `npm install` in packages/cli/
   - Links CLI globally with `npm link`
   - Reports any npm errors

7. **Reinstalls Skills**
   - Copies skill files to `~/.claude/commands/ralph/`
   - Updates all Claude Code command definitions
   - Skips if `--skip-skills` is provided

8. **Verifies Installation**
   - Confirms new version is active
   - Reports version change (old -> new)
   - Shows success/failure status

### Prerequisites

- Ralph must be installed from git (not npm)
- `.git` directory must exist in ralph installation
- Git must be installed and configured
- npm must be available
- Network access to origin remote

### Output Examples

**Check Only (`--check`):**

```
Update Status
  Current version: 1.0.0 (abc1234)
  Remote version:  1.0.1 (def5678)
  Branch:          main -> origin/main

  Updates available!

  Run 'ralph update' to install the latest version.

  Recent changes:
    def5678 feat: add new features
    abc9999 fix: bug fixes
```

**Already Up to Date:**

```
Update Status
  Current version: 1.0.1 (def5678)
  Remote version:  1.0.1 (def5678)
  Branch:          main -> origin/main

  Already up to date.
```

**Successful Update:**

```
========================================
   Updating Ralph
========================================

  1.0.0 (abc1234) -> 1.0.1 (def5678)

[INFO] Pulling latest changes...
[OK] Pulled latest changes
[INFO] Installing npm dependencies...
[OK] Installed npm dependencies
[INFO] Linking CLI globally...
[OK] Linked CLI globally
[INFO] Installing Claude Code skills...
[OK] Installed 14 skill files to ~/.claude/commands/ralph

========================================
   Update Complete!
========================================

  Version: 1.0.0 -> 1.0.1

  Verify with: ralph --version
```

**Error: Uncommitted Changes:**

```
[ERROR] Ralph installation has uncommitted local changes

Options:
  1. Commit or stash your changes first
  2. Use --force to update anyway (may lose local changes)
```

**Error: Not a Git Repository:**

```
[ERROR] Ralph installation directory is not a git repository: /path/to/ralph

The update command requires ralph to be installed from git.
If you installed via npm, update with: npm update -g @ralph/cli
```

### Related Commands

- `ralph --version` - Check current version
- `ralph list` - View all loops
- `ralph create <name>` - Create new loop
- `ralph uninstall` - Remove Ralph completely

### Troubleshooting

**Error: "Ralph installation directory is not a git repository"**
- Ralph must be installed from git, not npm
- Clone from: `git clone https://github.com/snarktank/ralph.git`

**Error: "Ralph installation has uncommitted local changes"**
- Commit or stash your changes first
- Or use `--force` to discard local changes (WARNING: loses changes)

**Error: "Failed to fetch from remote"**
- Check your network connection
- Verify git remote configuration: `git remote -v`
- Try `git fetch origin` manually

**Error: "Failed to pull changes"**
- There may be merge conflicts
- Resolve manually or use `--force` to reset

**Error: "npm link failed (may need sudo)"**
- Try: `cd packages/cli && sudo npm link`
- Or check npm permissions and configuration

**Skills not updating in Claude Code**
- Ensure `~/.claude/commands/ralph/` directory exists
- Check file permissions
- Restart Claude Code CLI

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/update.sh`.

The update command provides safe version management for Ralph installations:

**Key Features:**

1. **Safe Update Checking**
   - Check for updates without installing (`--check`)
   - Shows version comparison and recent changes
   - No modifications to filesystem

2. **Uncommitted Change Protection**
   - Detects local modifications
   - Prevents accidental loss of changes
   - Override with `--force` when intended

3. **Automatic Dependency Management**
   - Reinstalls npm dependencies after update
   - Re-links CLI globally
   - Ensures consistent state

4. **Claude Code Integration**
   - Automatically reinstalls skill files
   - Updates command definitions
   - Skip with `--skip-skills` if not needed

**Update Flow:**

1. Validate installation is git-based
2. Check for uncommitted local changes
3. Fetch latest from remote
4. Compare versions (abort if up-to-date)
5. Pull changes (normal) or reset (force)
6. Install npm dependencies
7. Link CLI globally
8. Install Claude Code skills
9. Report success with version change

**Force Mode Behavior:**

When `--force` is specified:
- Ignores uncommitted local changes
- Uses `git reset --hard` instead of `git pull`
- Completely replaces local files with remote version
- Use with caution - local changes will be lost

**Skills Installation:**

Skills are copied from `packages/cli/skills/ralph/` to `~/.claude/commands/ralph/`. This makes Ralph commands available as `/ralph:*` in Claude Code CLI.
