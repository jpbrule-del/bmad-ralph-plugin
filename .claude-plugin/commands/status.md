You are executing the **Ralph Status** command to monitor loop execution.

## Command Overview

**Purpose:** Monitor a Ralph automation loop's execution in real-time or with a single snapshot

**Agent:** Ralph CLI

**Output:** Live dashboard or single snapshot showing loop progress, current story, quality gates, and recent activity

---

## Execution

Run the ralph CLI status command with a loop name:

```bash
ralph status <loop-name>
```

### Required Arguments

- `<loop-name>` - Name of the loop to monitor (must exist in `ralph/loops/` or `ralph/archive/`)

### Options

- `--once` - Display status once and exit (snapshot mode)
- `--refresh <seconds>` - Set custom refresh rate for live monitoring (default: 2 seconds)

### Examples

```bash
# Monitor loop in real-time (default 2-second refresh)
ralph status my-sprint

# Single status snapshot (no live updates)
ralph status my-sprint --once

# Live monitoring with custom 5-second refresh
ralph status my-sprint --refresh 5

# Monitor archived loop
ralph status 2026-01-10-completed-sprint --once
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Validates loop exists in `ralph/loops/` or `ralph/archive/`
   - Ensures `config.json` exists and has valid structure
   - Supports archived loops (read-only status)

2. **Displays Loop Status**
   - Shows loop name, project, branch, and state (Running/Idle/Archived)
   - If running, shows the active process ID
   - Indicates whether loop is archived

3. **Shows Current Story**
   - Displays current story ID and title
   - Shows story points and epic association
   - Tracks attempt count vs stuck threshold
   - Highlights stuck stories in red
   - Shows time elapsed on current story

4. **Tracks Overall Progress**
   - Stories completed vs total (with percentage)
   - Visual progress bar for overall sprint progress
   - Visual progress bar for current epic (if applicable)
   - Iterations run vs max iterations (with color coding)
   - Average iterations per story

5. **Estimates Time to Completion**
   - Calculates average time per story based on completion timestamps
   - Shows remaining stories count
   - Provides estimated time to completion (ETA)
   - Requires at least 2 completed stories for accurate estimation

6. **Displays Quality Gates Status**
   - Shows each configured quality gate (typecheck, test, lint, build)
   - Indicates pass/fail status with color coding (✓ green, ✗ red)
   - Shows when gates were last executed
   - Warns if no quality gates are enabled

7. **Shows Recent Activity**
   - Displays last 10 significant events from `progress.txt`
   - Color-codes events (iteration starts, completions, failures, stuck events)
   - Helps understand recent loop behavior

8. **Live Dashboard Mode** (default, without --once)
   - Refreshes automatically at specified interval
   - Interactive keyboard controls:
     - `q` - Quit the status monitor
     - `r` - Refresh immediately (don't wait for interval)
     - `l` - View full log in pager (less/cat)
   - Flicker-free updates (uses ANSI escape sequences)
   - Graceful cleanup on exit (restores cursor and terminal)

9. **Snapshot Mode** (with --once)
   - Displays status once and exits
   - Useful for scripting or quick status checks
   - No terminal manipulation or keyboard handling

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loop must exist (`ralph create <name>`)
- `docs/sprint-status.yaml` must be valid and accessible
- `jq` and `yq` must be installed for JSON/YAML parsing

### Progress Information

The status command displays detailed progress tracking:

**Story Progress:**
- Stories completed / total stories
- Current story with attempt tracking
- Epic-level progress (points completed / total points)
- Visual progress bars

**Iteration Tracking:**
- Iterations run / max iterations
- Color coding:
  - Green: < 60% of max iterations
  - Yellow: 60-79% of max iterations
  - Red: ≥ 80% of max iterations

**Time Tracking:**
- Time elapsed on current story
- Average time per story
- Estimated time to completion

### Quality Gate Status

Quality gates are displayed with their current status:

- **✓ PASS** (green) - Gate passed in last execution
- **✗ FAIL** (red) - Gate failed in last execution
- **○ NO DATA** (gray) - No execution data available
- **○ (disabled)** (gray) - Gate not configured

The status command parses `progress.txt` to determine the most recent quality gate execution results.

### Lock File Detection

The status command detects if a loop is currently running by checking for:

- Lock file at `ralph/loops/<name>/.lock`
- Whether the process ID in the lock file is still active
- Automatically detects stale lock files (process no longer running)

### Related Commands

- `ralph run <name>` - Execute the automation loop
- `ralph show <name>` - Display detailed loop configuration
- `ralph list` - List all loops
- `ralph create <name>` - Create a new automation loop

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph

**Error: "Loop does not exist"**
- Run `ralph list` to see available loops
- Create loop with `ralph create <name>`

**Error: "Loop configuration file not found"**
- The loop's `config.json` is missing or corrupted
- Restore from backup or recreate the loop

**Status shows "No story currently in progress"**
- Loop may not have started yet
- All stories may be completed
- Check `docs/sprint-status.yaml` for available stories

**Quality gates show "NO DATA"**
- Loop hasn't run yet, or no stories completed
- Quality gates haven't been executed
- Run `ralph run <name>` to execute stories

**Live dashboard is flickering**
- Terminal may not support ANSI escape sequences properly
- Use `--once` flag for single snapshot instead
- Try different terminal emulator

**Estimated time shows "Calculating..."**
- Need at least 2 completed stories for time estimation
- Complete more stories to get accurate estimates
- Early estimates may not be accurate

**Can't quit live monitor with 'q' key**
- Try Ctrl+C to force exit
- Terminal may not be in interactive mode
- Check if running in a non-interactive shell

**"Permission denied" when reading progress.txt**
- File permissions issue
- Run with appropriate user permissions
- Check file ownership with `ls -la ralph/loops/<name>/progress.txt`

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/status.sh`.

The status command provides two modes:

**Snapshot Mode** (--once):
- Single status display
- No terminal manipulation
- Useful for scripts, cron jobs, or quick checks
- Exits immediately after display

**Live Dashboard Mode** (default):
- Real-time monitoring with auto-refresh
- Interactive keyboard controls (q, r, l)
- ANSI escape sequences for flicker-free updates
- Graceful cleanup on exit

The status command reads from multiple sources:

1. **config.json** - Loop configuration, statistics, story attempts
2. **docs/sprint-status.yaml** - Story definitions, epic progress, total story count
3. **progress.txt** - Current story, recent activity, quality gate results
4. **.lock** - Running state detection

The command calculates:

- Progress percentages (stories, iterations, epic points)
- Time estimates (average time per story, ETA)
- Quality gate status (by parsing progress.txt backwards)
- Time elapsed on current story (using file modification time)

Color coding enhances readability:

- **Green** - Success, passing, healthy state
- **Yellow** - Warning, approaching thresholds
- **Red** - Failure, stuck, critical state
- **Cyan** - Information, section headers
- **Dim** - Disabled or unavailable features

The live dashboard uses ANSI control sequences:

- Cursor positioning (no screen clearing for flicker-free updates)
- Cursor show/hide (prevents flickering during updates)
- Line clearing (ensures clean updates when text lengths change)
- Terminal restoration on exit (preserves user's terminal state)
