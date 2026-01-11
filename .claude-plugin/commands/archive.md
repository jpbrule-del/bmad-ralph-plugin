You are executing the **Ralph Archive** command to archive a completed loop.

## Command Overview

**Purpose:** Archive a completed loop with mandatory feedback collection for historical record and future improvement

**Agent:** Ralph CLI

**Output:** Loop moved to `ralph/archive/YYYY-MM-DD-<name>/` with feedback.json saved

---

## Execution

Run the ralph CLI archive command with loop name:

```bash
ralph archive <loop-name>
```

### Required Arguments

- `<loop-name>` - Name of the loop to archive

### Options

- `--skip-feedback` - Skip feedback collection (not recommended, primarily for testing/automation)

### Examples

```bash
# Archive a completed loop (with feedback)
ralph archive sprint-1

# Archive loop without feedback (not recommended)
ralph archive sprint-1 --skip-feedback

# Archive after epic completion
ralph archive feature-auth

# Archive for historical record
ralph archive experiment-config
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Validates loop exists in active loops
   - Checks loop is not already archived
   - Checks loop is not currently running (.lock file)
   - Validates config.json exists in loop directory

2. **Collects Mandatory Feedback** (unless `--skip-feedback`)
   - Overall satisfaction rating (1-5 scale)
   - Number of stories requiring manual intervention
   - What worked well (required text)
   - What should be improved (required text)
   - Would run this configuration again (yes/no)
   - Displays feedback summary for confirmation
   - Cancels archive if feedback not confirmed

3. **Creates Archive Directory**
   - Creates `ralph/archive/` if it doesn't exist
   - Generates date-based archive name: `YYYY-MM-DD-<loop-name>`
   - Validates archive destination doesn't already exist

4. **Updates Loop Metadata**
   - Adds `archivedAt` timestamp to config.json
   - Uses atomic write for safety (temp file + validate + move)

5. **Moves Loop to Archive**
   - Moves entire loop directory from `ralph/loops/` to `ralph/archive/`
   - Preserves all files: config.json, progress.txt, loop.sh, prompt.md
   - Preserves execution statistics and story notes

6. **Saves Feedback Data**
   - Creates `feedback.json` in archive directory
   - Stores all feedback responses with metadata
   - Uses atomic write for safe JSON storage
   - Includes loop statistics with feedback

7. **Confirms Success**
   - Shows success message with archive location
   - Displays archive timestamp
   - Suggests related commands for viewing archived loops

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loop must exist in active loops (`ralph/loops/<name>/`)
- Loop must not be currently running (no .lock file with active PID)
- Loop must not already be archived
- `jq` must be installed for JSON manipulation

### Feedback Questionnaire

The feedback questionnaire collects valuable data for improving Ralph's effectiveness:

**Question 1: Overall Satisfaction**
- Scale: 1 (Very Dissatisfied) to 5 (Very Satisfied)
- Required: Must enter 1-5

**Question 2: Manual Interventions**
- Count of stories requiring manual fixes
- Range: 0 to total stories
- Defaults to 0 if empty

**Question 3: What Worked Well?**
- Free text response describing successful aspects
- Required: Cannot be empty
- Captures what configurations/patterns were effective

**Question 4: What Should Be Improved?**
- Free text response describing areas for improvement
- Required: Cannot be empty
- Captures pain points and opportunities

**Question 5: Run Again?**
- Yes/No question about reusing this configuration
- Indicates confidence in loop setup

**Confirmation:**
- Displays summary of all responses
- Requires confirmation to submit
- Can cancel to abort archive

### Feedback JSON Structure

The feedback.json file contains:

```json
{
  "loopName": "sprint-1",
  "timestamp": "2026-01-11T15:30:00Z",
  "responses": {
    "overallSatisfaction": 4,
    "manualInterventions": 2,
    "workedWell": "Quality gates caught issues early",
    "shouldImprove": "Stuck detection could be more sensitive",
    "runAgain": "yes"
  },
  "loopStats": {
    "storiesCompleted": 10,
    "totalStories": 12,
    "iterationsRun": 15
  }
}
```

### Archive Directory Structure

After archiving, the directory structure looks like:

```
ralph/archive/2026-01-11-sprint-1/
├── config.json         # Loop configuration with archivedAt timestamp
├── progress.txt        # Full execution history
├── loop.sh            # Loop execution script
├── prompt.md          # Loop prompt template
└── feedback.json      # Feedback questionnaire responses (if not skipped)
```

### Related Commands

- `ralph unarchive <name>` - Restore archived loop to active loops
- `ralph list --archived` - List all archived loops with dates
- `ralph show <archive-name>` - View archived loop details and feedback
- `ralph clone <archive-name> <new-name>` - Create new loop from archived config
- `ralph feedback-report` - View aggregate feedback analytics across all archives

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph
- Creates the `ralph/` directory structure

**Error: "Loop does not exist"**
- Run `ralph list` to see available active loops
- Loop name may be misspelled
- Loop may already be archived (check `ralph list --archived`)

**Error: "Loop is already archived"**
- Use `ralph list --archived` to see archived loops
- Archived loops cannot be archived again
- If you need to make changes, use `ralph unarchive` first

**Error: "Cannot archive loop while it is running"**
- Loop is currently executing (has active .lock file)
- Wait for loop to complete or stop it first
- Check running process: `ps aux | grep ralph`
- Remove stale lock if process is dead: `rm ralph/loops/<name>/.lock`

**Error: "Loop configuration file not found"**
- Loop directory is incomplete or corrupted
- config.json is missing from loop directory
- May need to recreate loop or fix manually

**Error: "Archive destination already exists"**
- You've already archived a loop with this name today
- Archive names use date prefix: YYYY-MM-DD-<name>
- Options:
  - Delete existing archive first
  - Wait until tomorrow to archive again
  - Manually rename existing archive

**Warning: "Failed to save feedback to archive"**
- Loop was archived successfully but feedback save failed
- Archive operation continues (loop is already moved)
- Feedback data may be lost
- Check disk space and permissions

**Feedback collection cancelled**
- User declined to confirm feedback submission
- Archive operation is aborted
- Loop remains in active loops
- Can retry with same or different feedback
- Can use `--skip-feedback` to bypass (not recommended)

**Feedback validation errors**
- Satisfaction must be 1-5
- Manual interventions must be 0 to total stories
- Text responses cannot be empty
- Yes/no must be y/n
- Re-prompt until valid input provided

**Permission denied errors**
- Check write permissions on `ralph/archive/` directory
- Check permissions on source loop directory
- May need to run with appropriate permissions

**Archived loop doesn't show in list**
- Run `ralph list --archived` (not just `ralph list`)
- Check archive directory: `ls ralph/archive/`
- Archive name format: YYYY-MM-DD-<loop-name>

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/archive.sh`.

The archive command provides a comprehensive solution for preserving completed loop executions:

**Key Features:**

1. **Mandatory Feedback Collection**
   - Captures valuable learning from each loop execution
   - Structured questionnaire for consistent data
   - Required questions prevent skipping important insights
   - Confirmation step prevents accidental submission
   - Can be skipped with `--skip-feedback` for automation/testing

2. **Safe Move Operation**
   - Checks loop is not running before archiving
   - Atomic metadata updates (temp file + validate + move)
   - All-or-nothing move operation
   - Preserves all loop files and history
   - Creates archive directory if needed

3. **Date-Based Organization**
   - Archive names prefixed with YYYY-MM-DD
   - Allows multiple archives of same loop name over time
   - Easy to sort chronologically
   - Prevents duplicate archives on same day
   - Clear historical record

4. **Complete Data Preservation**
   - Preserves loop configuration (quality gates, thresholds, etc.)
   - Preserves execution statistics (iterations, story attempts)
   - Preserves progress log with full history
   - Preserves loop script and prompt template
   - Adds archive timestamp to metadata
   - Stores feedback responses in separate file

5. **Read-Only Historical Record**
   - Archived loops are meant for reference only
   - Cannot be executed or edited in place
   - Use `ralph unarchive` to restore for modifications
   - Use `ralph clone` to create new loop from archived config
   - Prevents accidental changes to historical data

**Data Flow:**

1. User runs `ralph archive <loop-name>`
2. Command validates prerequisites (Ralph init, loop exists, not running, not archived)
3. Command checks for active .lock file with running process
4. Command displays feedback questionnaire (unless --skip-feedback)
5. User provides responses to 5 required questions
6. Command displays feedback summary for confirmation
7. If not confirmed, aborts archive operation
8. Creates `ralph/archive/` directory if needed
9. Generates archive name: `YYYY-MM-DD-<loop-name>`
10. Updates config.json with `archivedAt` timestamp (atomic write)
11. Moves loop directory: `mv ralph/loops/<name> ralph/archive/<archive-name>`
12. Saves feedback.json to archive directory (atomic write)
13. Shows success message with archive location

**Feedback Data Collection:**

The questionnaire.sh module handles feedback collection:
- Sources from `packages/cli/lib/feedback/questionnaire.sh`
- Presents interactive prompts in terminal
- Validates each response before accepting
- Trims whitespace from text responses
- Converts yes/no to consistent format
- Generates structured JSON output
- Returns JSON string for storage

**Atomic Write Pattern:**

Both config.json update and feedback.json storage use atomic writes:
```bash
# Update metadata
jq '. + {archivedAt: $timestamp}' config.json > temp_file
mv temp_file config.json  # Atomic operation

# Save feedback
atomic_write_json feedback.json "$feedback_json"
```

This ensures:
- Invalid JSON never overwrites files
- Updates are atomic (all-or-nothing)
- Failures detected before damage occurs

**Archive Metadata:**

The config.json in archived loops includes:
- All original configuration fields
- `archivedAt`: ISO 8601 timestamp of archive time
- `stats`: Preserved execution statistics
- `storyAttempts`: Preserved attempt tracking
- `storyNotes`: Preserved story history

**Lock File Handling:**

Before archiving, checks for running loop:
```bash
if [[ -f .lock ]] && kill -0 $(cat .lock); then
  error "Cannot archive while running"
fi
```

This prevents:
- Archiving a loop that's mid-execution
- Data corruption from concurrent access
- Lost work from incomplete iterations

**Use Cases:**

1. **Sprint Completion**
   - Archive loop after sprint finishes
   - Capture feedback on what worked
   - Preserve history for retrospectives
   - Start fresh loop for next sprint

2. **Epic Completion**
   - Archive after completing epic
   - Document successes and challenges
   - Reference for similar epics in future
   - Compare feedback across epics

3. **Experiment Conclusion**
   - Archive experimental configurations
   - Record what was learned
   - Keep for reference but don't clutter active loops
   - Decide whether to run again based on feedback

4. **Historical Record**
   - Archive successful loops for future reference
   - Build knowledge base of effective configurations
   - Analyze feedback trends over time
   - Improve loop design based on patterns

**Best Practices:**

1. **Thoughtful Feedback:** Take time to provide meaningful feedback responses
2. **Regular Archiving:** Archive completed loops promptly to keep workspace clean
3. **Review Feedback:** Use `ralph feedback-report` to identify improvement patterns
4. **Clone Success:** Clone archived loops with good feedback for future use
5. **Keep Archives:** Don't delete archives - they're valuable historical data
6. **Archive Early:** Archive when loop is complete, not months later
7. **Honest Assessment:** Provide honest feedback for accurate analytics
8. **Document Learnings:** Use feedback to capture what worked and what didn't

**Integration with Other Commands:**

- `ralph list --archived`: Displays archived loops with dates and feedback scores
- `ralph show <archive-name>`: Shows full details including feedback responses
- `ralph unarchive <name>`: Restores to active loops (optionally resets stats)
- `ralph clone <archive-name> <new>`: Creates new loop from archived config
- `ralph feedback-report`: Aggregates feedback across all archives for analytics
- `ralph delete <name>`: Cannot delete archived loops (safety feature)

**Skipping Feedback:**

The `--skip-feedback` flag is provided for:
- Automated workflows where prompts aren't possible
- Testing scenarios
- Situations where feedback isn't valuable

However, it's strongly discouraged for normal use because:
- Feedback provides valuable improvement insights
- Analytics require consistent feedback data
- Historical context is lost without responses
- Future loop design depends on lessons learned
