You are executing the **Ralph List** command to view all automation loops.

## Command Overview

**Purpose:** Display all Ralph automation loops with their status, progress, and metadata

**Agent:** Ralph CLI

**Output:** Formatted table or JSON showing all active and/or archived loops sorted by last modification

---

## Execution

Run the ralph CLI list command:

```bash
ralph list
```

### Options

- `--active` - Show only active loops (in `ralph/loops/`)
- `--archived` - Show only archived loops (in `ralph/archive/`)
- `--json` - Output in JSON format instead of human-readable table

By default, shows both active and archived loops.

### Examples

```bash
# List all loops (active and archived)
ralph list

# List only active loops
ralph list --active

# List only archived loops
ralph list --archived

# Get JSON output for scripting
ralph list --json

# Pipe to jq for filtering
ralph list --json | jq '.loops[] | select(.storiesCompleted > 5)'
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Shows error message with initialization instructions if not initialized

2. **Scans Loop Directories**
   - Scans `ralph/loops/` for active loops (if --active or default)
   - Scans `ralph/archive/` for archived loops (if --archived or default)
   - Reads `config.json` from each loop directory

3. **Collects Loop Metadata**
   - Loop name (directory name)
   - Status (active or archived)
   - Created date (from `config.json` generatedAt field)
   - Stories completed vs total stories
   - Total iterations run
   - Archive date (for archived loops, extracted from directory name prefix)
   - Feedback score (for archived loops with `feedback.json`)

4. **Sorts Results**
   - Sorts loops by last modification time (most recent first)
   - Ensures consistent ordering across invocations

5. **Formats Output**

   **Human-Readable Table (default):**
   - Standard view: NAME, STATUS, CREATED, STORIES, ITERATIONS
   - Archived-only view: NAME, STATUS, ARCHIVED, STORIES, ITERATIONS, FEEDBACK
   - Color-coded status (green=active, yellow=archived)
   - Color-coded feedback scores (red=1-2, yellow=3, green=4-5)
   - Shows summary count at bottom

   **JSON Output (--json flag):**
   - Array of loop objects with all metadata
   - Includes fields: name, status, createdAt, storiesCompleted, totalStories, iterations
   - For archived loops: archiveDate, feedbackScore
   - Includes total count

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loops created with `ralph create <name>`
- `jq` must be installed for JSON parsing

### Output Format

**Standard Table View:**

```
Ralph Loops

NAME                 STATUS     CREATED              STORIES         ITERATIONS
----                 ------     -------              -------         ----------
plugin-sprint        active     2026-01-11           9/40            18
api-refactor         active     2026-01-10           3/12            8

Total loops: 2
```

**Archived-Only View:**

```
Ralph Loops

NAME                      STATUS     ARCHIVED      STORIES         ITERATIONS  FEEDBACK
----                      ------     --------      -------         ----------  --------
2026-01-09-completed      archived   2026-01-09    15/15           32          5/5
2026-01-08-feature-work   archived   2026-01-08    10/10           24          4/5

Total loops: 2
```

**JSON Output:**

```json
{
  "loops": [
    {
      "name": "plugin-sprint",
      "status": "active",
      "createdAt": "2026-01-11T07:43:21Z",
      "storiesCompleted": 9,
      "totalStories": 40,
      "iterations": 18,
      "archiveDate": null,
      "feedbackScore": null
    },
    {
      "name": "2026-01-09-completed",
      "status": "archived",
      "createdAt": "2026-01-08T14:20:00Z",
      "storiesCompleted": 15,
      "totalStories": 15,
      "iterations": 32,
      "archiveDate": "2026-01-09",
      "feedbackScore": 5
    }
  ],
  "total": 2
}
```

### Loop Status Indicators

**Active Loops:**
- Located in `ralph/loops/`
- Currently being worked on or available to run
- Can be executed with `ralph run <name>`
- Can be monitored with `ralph status <name>`

**Archived Loops:**
- Located in `ralph/archive/`
- Completed and moved to archive
- Directory name prefixed with date (YYYY-MM-DD-name)
- May include `feedback.json` with satisfaction scores
- Read-only, can be viewed but not executed
- Can be restored with `ralph unarchive <name>`

### Story Count Format

Stories are displayed as "completed/total":
- `9/40` - 9 stories completed out of 40 total
- `15/15` - All stories completed (100%)
- `0/12` - No stories completed yet

### Feedback Score Format

For archived loops with feedback:
- `5/5` - Excellent (green)
- `4/5` - Good (green)
- `3/5` - Average (yellow)
- `2/5` - Poor (red)
- `1/5` - Very poor (red)
- `N/A` - No feedback provided

### Related Commands

- `ralph create <name>` - Create a new automation loop
- `ralph status <name>` - Monitor a loop's execution
- `ralph show <name>` - View detailed loop configuration
- `ralph archive <name>` - Archive a completed loop
- `ralph unarchive <name>` - Restore an archived loop

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph
- Creates the `ralph/` directory structure

**"No loops found"**
- No loops have been created yet
- Run `ralph create <name>` to create a loop
- If using --active or --archived, try without filter to see all loops

**Loop shows 0 total stories**
- Loop's `config.json` may be corrupted or incomplete
- `storyAttempts` field may be empty
- Loop may have been created but not fully initialized

**Loop missing from list**
- Loop directory may not contain `config.json`
- Directory may not be in `ralph/loops/` or `ralph/archive/`
- Check directory structure with `ls -la ralph/loops/`

**JSON output is malformed**
- Loop data may contain special characters
- `jq` may not be installed or is outdated
- Try human-readable output first to identify issue

**Archived loop shows wrong archive date**
- Archive date is extracted from directory name prefix
- Directory must be named `YYYY-MM-DD-<name>`
- If manually moved, rename to match expected format

**Feedback score not showing**
- Archived loop may not have `feedback.json`
- Loop may have been archived with `--skip-feedback`
- Check if file exists: `ls ralph/archive/*/feedback.json`

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/list.sh`.

The list command provides a quick overview of all automation loops in the project, helping users:

- See what loops are active and can be executed
- Check progress on running loops
- Review archived loops and their completion history
- Export loop data for analysis or reporting

**Key Features:**

1. **Dual Output Formats**
   - Human-readable table for terminal viewing
   - JSON format for scripting and automation

2. **Flexible Filtering**
   - View all loops (default)
   - Filter to active loops only (--active)
   - Filter to archived loops only (--archived)

3. **Rich Metadata Display**
   - Status indicators with color coding
   - Progress tracking (stories completed/total)
   - Iteration counts for effort tracking
   - Archive dates and feedback scores

4. **Sorting**
   - Loops sorted by last modification time
   - Most recently modified loops appear first
   - Helps identify stale or abandoned loops

**Data Sources:**

The command reads data from:
- `ralph/loops/*/config.json` - Active loop metadata
- `ralph/archive/*/config.json` - Archived loop metadata
- `ralph/archive/*/feedback.json` - User feedback scores

**Loop Discovery:**

Active loops are discovered by scanning `ralph/loops/` for directories containing `config.json`. Archived loops are discovered similarly in `ralph/archive/`, with the additional constraint that directory names should follow the `YYYY-MM-DD-<name>` pattern for proper archive date extraction.

**Story Counting:**

Total stories are counted from the `storyAttempts` object in `config.json`, which tracks all stories that have been attempted or completed in the loop. This may differ from the total story count in `docs/sprint-status.yaml` if the loop was created with an epic filter.

**JSON Schema:**

The JSON output format is designed for easy parsing and filtering with tools like `jq`. Each loop object includes null values for fields that don't apply (e.g., archiveDate and feedbackScore for active loops) to maintain consistent schema across all loops.
