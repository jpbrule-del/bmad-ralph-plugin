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
- `--keep-projects` - Don't remove project-level ralph/ directories
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
```

### What It Removes

1. **Claude Code Skills** - `~/.claude/commands/ralph/`
2. **Global CLI** - Unlinks ralph command from npm
3. **Project ralph/ Directory** - Unless --keep-projects
4. **Git Branches** - All branches matching `ralph/*`
5. **Source Directory** - Shows location (manual removal only)

### Prerequisites

- Ralph must be installed
- Write permissions to ~/.claude/commands/
- Git access for branch deletion (if applicable)

### Related Commands

- `ralph update` - Update to latest version
- `ralph list` - View all loops before uninstalling
- `ralph archive <name>` - Archive loops before uninstalling
