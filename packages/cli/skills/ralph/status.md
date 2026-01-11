You are executing the **Ralph Status** command to monitor loop execution.

## Command Overview

**Purpose:** Display real-time progress of a running loop

**Agent:** Ralph CLI

**Output:** Terminal dashboard with progress visualization

---

## Execution

Run the ralph CLI status command:

```bash
ralph status <loop-name>
```

### Options

- `--once` - Show single snapshot, don't refresh
- `--refresh <seconds>` - Set refresh rate (default: 2 seconds)

### Examples

```bash
# Monitor loop in real-time
ralph status sprint-2

# Show single snapshot
ralph status sprint-2 --once

# Custom refresh rate
ralph status sprint-2 --refresh 5
```

### Dashboard Features

- Overall progress (completed/total stories)
- Current story being worked on
- Iteration counter (current/max)
- Quality gate status (pass/fail indicators)
- Estimated time to completion
- Recent activity log tail

### Keyboard Controls (in watch mode)

- `q` - Quit dashboard
- `r` - Refresh immediately
- `l` - View full log (progress.txt)

### When to Use

- While `ralph run` is executing in another terminal
- To check on progress of a long-running loop
- To see if a loop has gotten stuck
