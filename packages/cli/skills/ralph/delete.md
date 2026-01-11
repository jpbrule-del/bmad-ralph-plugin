You are executing the **Ralph Delete** command to remove a loop.

## Command Overview

**Purpose:** Remove a loop and its files

**Agent:** Ralph CLI

**Output:** Loop directory removed

---

## Execution

Run the ralph CLI delete command:

```bash
ralph delete <loop-name>
```

### Options

- `--force` - Skip confirmation prompt

### Examples

```bash
# Delete with confirmation
ralph delete failed-experiment

# Delete without confirmation
ralph delete old-loop --force
```

### What It Does

1. Prompts for confirmation (unless --force)
2. Removes entire loop directory
3. Does NOT delete the git branch (warns user)

### Notes

- Cannot delete archived loops (unarchive first)
- Git branch is preserved for safety
- To delete git branch: `git branch -D ralph/<loop-name>`

### Related Commands

- `ralph archive <name>` - Archive instead of delete (preserves history)
- `ralph list` - See available loops
