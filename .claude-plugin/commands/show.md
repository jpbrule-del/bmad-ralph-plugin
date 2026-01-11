You are executing the **Ralph Show** command to display detailed loop information.

## Command Overview

**Purpose:** Display comprehensive details about a specific Ralph automation loop including configuration, story progress, and execution statistics

**Agent:** Ralph CLI

**Output:** Detailed loop information in human-readable format or JSON

---

## Execution

Run the ralph CLI show command with a loop name:

```bash
ralph show <loop-name>
```

### Required Arguments

- `<loop-name>` - Name of the loop to display (must exist in `ralph/loops/` or `ralph/archive/`)

### Options

- `--json` - Output in JSON format instead of human-readable format

### Examples

```bash
# Show detailed information for active loop
ralph show my-sprint

# Show information for archived loop
ralph show 2026-01-10-completed-sprint

# Get JSON output for scripting
ralph show my-sprint --json

# Pipe to jq for specific field extraction
ralph show my-sprint --json | jq '.config.qualityGates'
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Validates loop exists in `ralph/loops/` or `ralph/archive/`
   - Ensures `config.json` exists and has valid structure
   - Supports archived loops (includes feedback data)

2. **Displays Loop Status**
   - Shows if loop is active or archived
   - Active loops can be executed and modified
   - Archived loops are read-only with feedback data

3. **Shows Project Information**
   - Project name
   - Git branch name
   - Creation timestamp
   - Last activity timestamp (latest of created/started/completed)
   - Loop description (if provided)
   - Sprint status file path

4. **Displays Configuration**
   - Max iterations limit (default: 50)
   - Stuck threshold for story attempts (default: 3)
   - Custom instructions (if provided)
   - These settings control loop execution behavior

5. **Shows Quality Gates**
   - Typecheck command (if enabled)
   - Test command (if enabled)
   - Lint command (if enabled)
   - Build command (if enabled)
   - Displays enabled gates with ✓ and disabled gates with ○
   - Warns if no quality gates are enabled

6. **Displays Execution Statistics**
   - Total iterations run
   - Stories completed vs total stories
   - Completion percentage
   - Start timestamp (if loop has started)
   - Completion timestamp (if loop has finished)
   - Average iterations per story

7. **Shows Story Progress Breakdown**
   - Count of stories by attempt count:
     - 1 attempt (successful on first try) - green
     - 2 attempts (required retry) - yellow
     - 3+ attempts (at or above stuck threshold) - red
   - Lists individual stories at or above stuck threshold
   - Helps identify problematic stories requiring manual intervention

8. **Displays Feedback** (archived loops only)
   - Satisfaction rating (1-5) with color coding
   - Number of manual interventions required
   - What worked well (free text)
   - What should improve (free text)
   - Would run again (yes/no)
   - Feedback collection timestamp
   - Only shown if `feedback.json` exists in archived loop

9. **JSON Output Mode** (with --json flag)
   - Returns entire `config.json` content
   - Adds `loopName`, `isArchived`, and `lastActivity` fields
   - Useful for scripting and automation
   - Preserves all nested structures

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loop must exist (`ralph create <name>`)
- `jq` must be installed for JSON parsing

### Output Format

**Human-Readable Format (default):**

```
═══════════════════════════════════════
Loop Details: plugin-sprint
═══════════════════════════════════════

Status:         Active

───────────────────────────────────────
Project Information
───────────────────────────────────────
Project:        ralph
Branch:         ralph/plugin-sprint
Created:        2026-01-11T07:43:21Z
Last Activity:  2026-01-11T08:18:42Z
Description:    Loop: plugin-sprint
Sprint Status:  docs/sprint-status.yaml

───────────────────────────────────────
Configuration
───────────────────────────────────────
Max Iterations:   100
Stuck Threshold:  3

───────────────────────────────────────
Quality Gates
───────────────────────────────────────
✓ Typecheck:  npx tsc --noEmit
✓ Test:       npm test
✓ Lint:       npm run lint
✓ Build:      npm run build

───────────────────────────────────────
Execution Statistics
───────────────────────────────────────
Iterations Run:     20
Stories Completed:  10 / 40
Completion:         25%
Started At:         2026-01-11T07:43:57Z
Avg Iterations/Story: 2

───────────────────────────────────────
Story Progress
───────────────────────────────────────
Story Attempt Summary:

  1 attempt:   8 stories
  2 attempts:  2 stories
  3+ attempts: 0 stories

Loop location: ralph/loops/plugin-sprint
```

**JSON Format (--json flag):**

```json
{
  "project": "ralph",
  "loopName": "plugin-sprint",
  "branchName": "ralph/plugin-sprint",
  "description": "Loop: plugin-sprint",
  "generatedAt": "2026-01-11T07:43:21Z",
  "sprintStatusPath": "docs/sprint-status.yaml",
  "epicFilter": null,
  "config": {
    "maxIterations": 100,
    "stuckThreshold": 3,
    "qualityGates": {
      "typecheck": "npx tsc --noEmit",
      "test": "npm test",
      "lint": "npm run lint",
      "build": "npm run build"
    },
    "customInstructions": null
  },
  "stats": {
    "iterationsRun": 20,
    "storiesCompleted": 10,
    "startedAt": "2026-01-11T07:43:57Z",
    "completedAt": null,
    "averageIterationsPerStory": 2.0
  },
  "storyAttempts": {
    "STORY-001": 1,
    "STORY-002": 1,
    "STORY-003": 1
  },
  "storyNotes": {
    "STORY-001": {
      "title": "Create Plugin Manifest",
      "points": 3,
      "epic": "EPIC-001",
      "attempts": 1,
      "completedAt": "2026-01-11T07:48:05Z",
      "commit": "b3351a7"
    }
  },
  "isArchived": false,
  "lastActivity": "2026-01-11T08:18:42Z"
}
```

### Loop Status Indicators

**Active Loop:**
- Located in `ralph/loops/`
- Can be executed with `ralph run <name>`
- Can be monitored with `ralph status <name>`
- Can be edited with `ralph edit <name>`
- Can be archived with `ralph archive <name>`

**Archived Loop:**
- Located in `ralph/archive/`
- Directory name prefixed with date (YYYY-MM-DD-name)
- Read-only, cannot be executed or modified
- May include `feedback.json` with user feedback
- Can be restored with `ralph unarchive <name>`

### Configuration Details

**Max Iterations:**
- Maximum number of Claude invocations before loop stops
- Default: 50 iterations
- Prevents runaway loops consuming excessive resources
- Can be overridden per loop in `config.json`

**Stuck Threshold:**
- Number of consecutive failed attempts before story marked as stuck
- Default: 3 attempts
- When reached, loop pauses and alerts user
- Helps identify stories requiring human intervention

**Custom Instructions:**
- Optional additional instructions for Claude during loop execution
- Can include project-specific context or requirements
- Merged with standard Ralph prompt on each iteration

**Quality Gates:**
- Commands that must pass before committing story changes
- Common gates: typecheck, test, lint, build
- All enabled gates must pass (exit code 0)
- Disabled gates are skipped (shown as "○ (disabled)")

### Story Progress Analysis

The show command analyzes story attempts to help identify issues:

**1 Attempt (Green):**
- Story completed successfully on first try
- Indicates clear requirements and well-structured story
- Optimal scenario

**2 Attempts (Yellow):**
- Story required one retry
- May indicate minor issues or unclear requirements
- Generally acceptable

**3+ Attempts (Red):**
- Story at or above stuck threshold
- Requires manual intervention
- Possible causes:
  - Unclear or conflicting requirements
  - Technical blockers
  - Missing dependencies
  - Overly complex story (needs breakdown)

### Feedback Information (Archived Loops)

For archived loops with feedback, the show command displays:

**Satisfaction Rating (1-5):**
- 1-2: Poor experience (red) - significant issues
- 3: Average experience (yellow) - mixed results
- 4-5: Good experience (green) - successful automation

**Manual Interventions:**
- Count of times human had to intervene
- Lower is better (indicates more successful automation)

**Qualitative Feedback:**
- What worked well (positive aspects to replicate)
- What should improve (areas for enhancement)
- Would run again (overall confidence in approach)

### Related Commands

- `ralph status <name>` - Monitor loop execution in real-time
- `ralph list` - List all loops
- `ralph edit <name>` - Modify loop configuration
- `ralph run <name>` - Execute the loop
- `ralph archive <name>` - Archive a completed loop
- `ralph unarchive <name>` - Restore an archived loop

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph
- Creates the `ralph/` directory structure

**Error: "Loop does not exist"**
- Run `ralph list` to see available loops
- Loop name may be misspelled
- For archived loops, include or exclude date prefix as needed

**Error: "Loop configuration file not found"**
- The loop's `config.json` is missing or corrupted
- Loop directory may be incomplete
- Restore from backup or recreate the loop

**"No quality gates enabled" warning**
- Loop has no quality gates configured
- Changes will be committed without validation
- Configure gates in `config.json` or via `ralph config quality-gates`

**Story progress shows 0 total stories**
- Loop was created but never run
- `storyAttempts` object is empty
- Run `ralph run <name>` to begin executing stories

**JSON output is truncated or malformed**
- `config.json` may contain invalid JSON
- Validate with `jq . ralph/loops/<name>/config.json`
- Restore from backup if corrupted

**Feedback section not showing for archived loop**
- Loop was archived with `--skip-feedback` flag
- `feedback.json` file does not exist
- Check with `ls ralph/archive/*/feedback.json`

**Last activity timestamp seems incorrect**
- Timestamp is latest of: created, started, completed
- Reflects most recent significant event
- For completed loops, shows completion time

**Average iterations per story is 0**
- No stories have been completed yet
- Calculation requires at least 1 completed story
- Run loop to completion to see accurate metrics

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/show.sh`.

The show command provides a comprehensive single-loop view, ideal for:

- Understanding loop configuration before execution
- Reviewing progress on running loops
- Analyzing completed loops for insights
- Debugging stuck or failing loops
- Exporting loop data for reporting

**Key Features:**

1. **Dual Output Formats**
   - Human-readable format for terminal viewing
   - JSON format for scripting and automation

2. **Comprehensive Information**
   - Project metadata and timestamps
   - Configuration settings and quality gates
   - Execution statistics and progress
   - Story attempt breakdown
   - Feedback data (archived loops)

3. **Smart Data Analysis**
   - Calculates completion percentage
   - Identifies stuck stories
   - Color-codes status indicators
   - Groups stories by attempt count

4. **Support for Archived Loops**
   - Read-only access to archived loops
   - Displays feedback questionnaire responses
   - Shows archive-specific metadata

**Data Sources:**

The command reads data from:
- `ralph/loops/<name>/config.json` or `ralph/archive/<name>/config.json` - All loop metadata
- `ralph/archive/<name>/feedback.json` - User feedback (archived loops only)

**Loop Discovery:**

The command searches for loops in this order:
1. `ralph/loops/<name>` - Active loop with exact name
2. `ralph/archive/<name>` - Archived loop with exact name
3. `ralph/archive/*-<name>` - Archived loop with date prefix

This allows users to reference archived loops by name without remembering the date prefix.

**Configuration Schema:**

The `config.json` file contains:
- `project` - Project name
- `loopName` - Loop name
- `branchName` - Git branch for this loop
- `description` - Loop description
- `generatedAt` - Creation timestamp
- `sprintStatusPath` - Path to sprint status YAML
- `epicFilter` - Optional epic filter
- `config` - Configuration settings (maxIterations, stuckThreshold, qualityGates, customInstructions)
- `stats` - Execution statistics (iterationsRun, storiesCompleted, startedAt, completedAt, averageIterationsPerStory)
- `storyAttempts` - Map of story IDs to attempt counts
- `storyNotes` - Map of story IDs to completion metadata

**Story Attempt Tracking:**

The `storyAttempts` object tracks how many times each story was attempted:
- Key: Story ID (e.g., "STORY-001")
- Value: Number of attempts (integer)
- Used to identify stuck stories and calculate success rates

**Quality Gate Display:**

Quality gates are shown with visual indicators:
- ✓ (green) - Gate is enabled and command is configured
- ○ (dim) - Gate is disabled (null in config.json)

The show command displays the command that will be executed for each gate, helping users understand what validation will occur.

**Feedback Display:**

For archived loops, feedback is displayed with color coding:
- Satisfaction scores: Red (1-2), Yellow (3), Green (4-5)
- Would run again: Green (yes), Red (no)
- Manual interventions: Higher numbers indicate more problems

**JSON Schema:**

The JSON output includes the entire `config.json` content plus three additional fields:
- `loopName` - Loop name (extracted from directory name)
- `isArchived` - Boolean indicating archive status
- `lastActivity` - Latest timestamp (created/started/completed)

This schema is designed for easy parsing and filtering with tools like `jq`.
