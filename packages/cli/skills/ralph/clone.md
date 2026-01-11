You are executing the **Ralph Clone** command to copy a loop configuration.

## Command Overview

**Purpose:** Copy an existing loop to a new loop with reset statistics

**Agent:** Ralph CLI

**Output:** New loop at `ralph/loops/<destination>/`

---

## Execution

Run the ralph CLI clone command:

```bash
ralph clone <source> <destination>
```

### Examples

```bash
# Clone a successful configuration
ralph clone sprint-1 sprint-2

# Clone from archived loop
ralph clone 2026-01-10-auth-feature new-auth
```

### What It Does

1. Copies all loop files to new directory
2. Resets execution statistics to zero
3. Creates new git branch `ralph/<destination>`
4. Preserves configuration settings (quality gates, thresholds)

### Use Cases

- Reusing a successful configuration for new work
- Starting fresh with proven settings
- Creating variations of a loop for testing

### Related Commands

- `ralph create <name>` - Create new loop from scratch
- `ralph list` - See available loops to clone
