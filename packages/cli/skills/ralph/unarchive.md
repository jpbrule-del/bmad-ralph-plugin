You are executing the **Ralph Unarchive** command to restore an archived loop.

## Command Overview

**Purpose:** Restore a loop from archive back to active status

**Agent:** Ralph CLI

**Output:** Loop restored to `ralph/loops/<name>/`

---

## Execution

Run the ralph CLI unarchive command:

```bash
ralph unarchive <archive-name>
```

### Options

- `--reset-stats` - Reset execution statistics to zero
- `--no-branch` - Don't create git branch

### Examples

```bash
# Restore archived loop
ralph unarchive 2026-01-10-sprint-1

# Restore with fresh stats
ralph unarchive 2026-01-10-auth --reset-stats
```

### What It Does

1. Moves loop from `ralph/archive/` back to `ralph/loops/`
2. Preserves `feedback.json` for historical record
3. Creates new git branch (unless --no-branch)
4. Optionally resets execution statistics

### Use Cases

- Resume work on a previously archived loop
- Reuse a configuration with fresh state
- Investigate issues from a past run

### Related Commands

- `ralph archive <name>` - Archive a loop
- `ralph list --archived` - See available archives
- `ralph clone` - Alternative: clone instead of unarchive
