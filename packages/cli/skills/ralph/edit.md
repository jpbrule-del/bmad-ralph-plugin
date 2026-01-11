You are executing the **Ralph Edit** command to modify loop configuration.

## Command Overview

**Purpose:** Open loop configuration in your default editor

**Agent:** Ralph CLI

**Output:** Modified prd.json

---

## Execution

Run the ralph CLI edit command:

```bash
ralph edit <loop-name>
```

### What It Does

1. Opens `ralph/loops/<name>/prd.json` in `$EDITOR`
2. Validates JSON after editing
3. Warns if invalid JSON is detected

### Editable Settings

- `config.maxIterations` - Maximum loop iterations
- `config.stuckThreshold` - Failures before stopping
- `config.qualityGates` - Commands for each gate
- `userStories[].passes` - Mark stories as complete/incomplete
- `userStories[].attempts` - Reset attempt counters

### Environment Variable

Set your preferred editor:
```bash
export EDITOR=vim    # or code, nano, etc.
```

### Notes

- Cannot edit archived loops
- Changes take effect on next run

### Related Commands

- `ralph show <name>` - View configuration without editing
- `ralph config` - Edit global configuration
