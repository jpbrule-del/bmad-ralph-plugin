You are executing the **Ralph Run** command to start autonomous loop execution.

## Command Overview

**Purpose:** Execute a loop to autonomously implement stories via Claude Code CLI

**Agent:** Ralph CLI

**Output:** Implemented stories, git commits, updated sprint-status.yaml

---

## Execution

Run the ralph CLI run command:

```bash
ralph run <loop-name>
```

### Options

- `--dry-run` - Simulate execution without running Claude
- `--restart` - Start from beginning (ignore resume state)

### Examples

```bash
# Run a loop
ralph run sprint-2

# Dry run to verify configuration
ralph run sprint-2 --dry-run

# Restart from beginning
ralph run sprint-2 --restart
```

### What It Does

For each pending story:
1. Invokes Claude Code CLI with context from prompt.md
2. Claude implements the story
3. Runs quality gates (typecheck, test, lint, build)
4. If all gates pass: commits and marks story complete
5. If gates fail: increments attempt counter, retries
6. Updates `docs/sprint-status.yaml` with completion status
7. Logs progress to `progress.txt`

### Exit Conditions

| Exit Code | Status | Meaning |
|-----------|--------|---------|
| 0 | COMPLETE | All stories passed quality gates |
| 1 | STUCK | Story failed N consecutive times |
| 2 | MAX_ITERATIONS | Iteration limit reached |
| 130 | INTERRUPTED | User pressed Ctrl+C |

### Resume Capability

If interrupted, run `ralph run <loop-name>` again to resume from where it left off.

### Monitoring

While running, open another terminal and run:
```bash
ralph status <loop-name>
```
