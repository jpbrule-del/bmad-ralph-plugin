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

1. **Validates Installation** - Checks ralph is installed from git repository
2. **Checks for Updates** - Fetches from remote and compares versions
3. **Handles Uncommitted Changes** - Fails unless --force is used
4. **Pulls Latest Changes** - Normal pull or hard reset (--force)
5. **Reinstalls Dependencies** - npm install and npm link
6. **Reinstalls Skills** - Copies skill files to ~/.claude/commands/ralph/

### Prerequisites

- Ralph must be installed from git (not npm)
- Git must be installed and configured
- npm must be available
- Network access to origin remote

### Related Commands

- `ralph --version` - Check current version
- `ralph list` - View all loops
- `ralph uninstall` - Remove Ralph completely
