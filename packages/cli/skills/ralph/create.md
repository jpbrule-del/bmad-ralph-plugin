You are executing the **Ralph Create** command to create a new autonomous loop.

## Command Overview

**Purpose:** Create a new loop configuration for autonomous story implementation

**Agent:** Ralph CLI

**Output:** Loop files in `ralph/loops/<loop-name>/`

---

## Execution

Run the ralph CLI create command:

```bash
ralph create <loop-name>
```

### Options

- `--epic <id>` - Filter to a specific epic (e.g., EPIC-001)
- `--yes` - Skip interactive prompts, use defaults
- `--no-branch` - Don't create git branch

### Examples

```bash
# Create loop for all pending stories
ralph create sprint-2

# Create loop for specific epic
ralph create auth-feature --epic EPIC-002

# Create with defaults (no prompts)
ralph create quick-fix --yes
```

### What It Does

1. Reads `docs/sprint-status.yaml` for pending stories
2. Prompts for configuration (max iterations, stuck threshold, quality gates)
3. Generates loop files:
   - `ralph/loops/<name>/prd.json` - Loop configuration and state
   - `ralph/loops/<name>/prompt.md` - Context for Claude iterations
   - `ralph/loops/<name>/loop.sh` - Bash execution script
   - `ralph/loops/<name>/progress.txt` - Iteration log
4. Creates git branch `ralph/<loop-name>`

### Prerequisites

- `ralph init` must have been run
- `docs/sprint-status.yaml` must exist with pending stories

### Next Steps

After create, run:
- `ralph run <loop-name>` to start autonomous execution
