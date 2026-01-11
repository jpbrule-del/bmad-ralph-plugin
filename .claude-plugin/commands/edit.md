You are executing the **Ralph Edit** command to modify loop configuration.

## Command Overview

**Purpose:** Edit loop configuration file (config.json) in your preferred editor with validation

**Agent:** Ralph CLI

**Output:** Opens config.json in editor, validates changes, provides error recovery

---

## Execution

Run the ralph CLI edit command with a loop name:

```bash
ralph edit <loop-name>
```

### Required Arguments

- `<loop-name>` - Name of the loop to edit (must exist in `ralph/loops/`)

### Options

This command has no flags or options.

### Examples

```bash
# Edit active loop configuration
ralph edit my-sprint

# Edit recently created loop
ralph edit plugin-sprint

# After editing, validation occurs automatically
ralph edit my-sprint
# Opens in $EDITOR, validates JSON on save
```

### What It Does

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/` directory exists)
   - Validates loop exists in `ralph/loops/` (active loops only)
   - Checks `EDITOR` environment variable is set
   - Ensures `config.json` exists for the loop

2. **Prevents Editing Archived Loops**
   - Archived loops are read-only
   - If you try to edit an archived loop, you'll get an error
   - Use `ralph unarchive <name>` first to restore it to active loops

3. **Creates Safety Backup**
   - Creates `config.json.backup` before opening editor
   - Backup is automatically removed on successful save
   - Backup is used for recovery if validation fails

4. **Opens in Your Preferred Editor**
   - Uses `$EDITOR` environment variable
   - Common values: `vim`, `nano`, `code`, `emacs`
   - Set with: `export EDITOR=vim` (add to `.bashrc` or `.zshrc`)

5. **Validates JSON on Save**
   - Automatically validates JSON syntax when you close the editor
   - Uses `jq` to check for valid JSON structure
   - Invalid JSON prevents save and prompts for action

6. **Provides Error Recovery**
   - If validation fails, you get two options:
     1. Edit again - Reopens editor to fix the issue
     2. Restore backup and cancel - Reverts all changes
   - Backup is restored if you cancel or choose invalid option
   - No changes are permanently saved until validation passes

7. **Confirms Success**
   - Shows success message when configuration is validated
   - Removes backup file after successful validation
   - Loop is ready to use with updated configuration

### Prerequisites

- Ralph must be initialized (`ralph init`)
- Loop must exist and be active (`ralph create <name>`)
- `EDITOR` environment variable must be set
- `jq` must be installed for JSON validation

### Configuration File Structure

The `config.json` file contains:

```json
{
  "project": "your-project",
  "loopName": "loop-name",
  "branchName": "ralph/loop-name",
  "description": "Loop description",
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
    "iterationsRun": 0,
    "storiesCompleted": 0,
    "startedAt": null,
    "completedAt": null,
    "averageIterationsPerStory": 0
  },
  "storyAttempts": {},
  "storyNotes": {}
}
```

### Common Edits

**Change Max Iterations:**
```json
"config": {
  "maxIterations": 200
}
```

**Update Stuck Threshold:**
```json
"config": {
  "stuckThreshold": 5
}
```

**Add Custom Instructions:**
```json
"config": {
  "customInstructions": "Always include JSDoc comments for new functions"
}
```

**Modify Quality Gates:**
```json
"config": {
  "qualityGates": {
    "typecheck": null,
    "test": "npm test",
    "lint": "npm run lint",
    "build": "npm run build"
  }
}
```
Set to `null` to disable a gate, or provide a command string to enable it.

**Change Epic Filter:**
```json
"epicFilter": "EPIC-002"
```
This limits the loop to only execute stories from the specified epic.

**Update Description:**
```json
"description": "Plugin migration sprint for BMAD Ralph"
```

### Setting Your Editor

If `EDITOR` is not set, you'll get an error. Set it in your shell profile:

**Bash (~/.bashrc):**
```bash
export EDITOR=vim
```

**Zsh (~/.zshrc):**
```bash
export EDITOR=vim
```

**For Visual Studio Code:**
```bash
export EDITOR="code --wait"
```

**For Sublime Text:**
```bash
export EDITOR="subl -w"
```

After adding, reload your shell:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

### Related Commands

- `ralph show <name>` - View current configuration without editing
- `ralph config` - Manage global Ralph configuration
- `ralph create <name>` - Create a new loop with initial configuration
- `ralph unarchive <name>` - Restore archived loop to active (then edit)

### Troubleshooting

**Error: "Ralph is not initialized in this project"**
- Run `ralph init` first to initialize Ralph
- Creates the `ralph/` directory structure

**Error: "Loop does not exist"**
- Run `ralph list` to see available loops
- Loop name may be misspelled
- Only active loops can be edited

**Error: "Cannot edit archived loop"**
- Archived loops are read-only for data integrity
- Use `ralph unarchive <name>` first to restore it
- Then edit the restored active loop

**Error: "EDITOR environment variable is not set"**
- Set your preferred editor: `export EDITOR=vim`
- Add to `.bashrc` or `.zshrc` for persistence
- Reload shell with `source ~/.bashrc` or `source ~/.zshrc`

**Error: "Loop configuration file not found"**
- The loop's `config.json` is missing or corrupted
- Loop directory may be incomplete
- Recreate the loop with `ralph create <name>`

**Error: "Invalid JSON in configuration file"**
- You saved malformed JSON in the editor
- Choose option 1 to edit again and fix the syntax
- Choose option 2 to restore backup and cancel
- Common issues:
  - Missing commas between fields
  - Trailing commas (not allowed in JSON)
  - Unquoted property names
  - Unclosed braces or brackets
  - Use `jq` for validation: `jq . config.json`

**Configuration not taking effect**
- Changes apply on next `ralph run` invocation
- Currently running loops use old configuration
- Stop and restart the loop to pick up changes

**Backup file left behind**
- If process is killed, backup may remain: `config.json.backup`
- Safe to delete manually if edit was successful
- Or restore if you want to undo recent changes

**Editor opens but shows blank file**
- `config.json` may have been deleted or moved
- Check file exists: `ls ralph/loops/<name>/config.json`
- Recreate loop if file is missing

**Editor settings not working (code --wait)**
- Ensure editor is in PATH
- Test editor command separately: `code --wait /tmp/test.txt`
- Some editors require flags to wait for file close

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/edit.sh`.

The edit command provides a safe, validated way to modify loop configuration with these key features:

**Key Features:**

1. **Safety First**
   - Creates automatic backup before editing
   - Validates JSON syntax after changes
   - Provides error recovery options
   - No permanent changes until validation passes

2. **Editor Integration**
   - Uses standard `$EDITOR` environment variable
   - Works with any text editor (vim, nano, code, emacs, etc.)
   - Waits for editor to close before validating
   - Supports both terminal and GUI editors

3. **Error Recovery**
   - Interactive prompts on validation failure
   - Option to fix issues or revert changes
   - Clear error messages and guidance
   - Backup restoration on cancel

4. **Read-Only Protection**
   - Prevents editing archived loops
   - Maintains data integrity for completed work
   - Guides users to unarchive first if needed

**Data Flow:**

1. User runs `ralph edit <name>`
2. Command validates prerequisites (Ralph initialized, loop exists, EDITOR set)
3. Command locates loop in `ralph/loops/` (rejects archived loops)
4. Backup created: `config.json` → `config.json.backup`
5. Editor opens with `config.json`
6. User makes changes and closes editor
7. JSON validation runs with `jq`
8. If valid: backup removed, success message shown
9. If invalid: user prompted to edit again or restore backup

**Loop Discovery:**

The command searches for loops in this order:
1. `ralph/loops/<name>` - Active loop with exact name
2. `ralph/archive/<name>` - Archived loop (rejected with error)
3. `ralph/archive/*-<name>` - Archived loop with date prefix (rejected with error)

This prevents accidental editing of archived loops while providing clear guidance.

**Validation Process:**

The command uses `jq empty <file>` to validate JSON:
- Exit code 0: Valid JSON, changes accepted
- Exit code non-zero: Invalid JSON, user prompted for action

This catches common errors:
- Syntax errors (missing commas, brackets)
- Invalid JSON structure
- Encoding issues

**Configuration Guidelines:**

When editing `config.json`, be careful with:

**Max Iterations (integer):**
- Range: 1-1000 recommended
- Default: 50 for loops created from CLI
- Higher values allow longer automation runs
- Lower values prevent runaway loops

**Stuck Threshold (integer):**
- Range: 1-10 recommended
- Default: 3 attempts
- Higher values give more retry attempts
- Lower values catch problems faster

**Quality Gates (object):**
- Each gate is either `null` (disabled) or a command string
- Command must exit with code 0 for success
- Commands run from project root directory
- All enabled gates must pass before commit

**Custom Instructions (string or null):**
- Additional context for Claude during execution
- Use for project-specific requirements
- Keep concise to avoid token bloat
- Set to `null` if not needed

**Epic Filter (string or null):**
- Limits loop to stories from specified epic
- Format: "EPIC-001" (the epic ID)
- Set to `null` to include all epics
- Useful for focused sprints

**Stats Object (read-only in practice):**
- Updated automatically by loop execution
- Can be manually reset if needed
- Edit with caution as it affects reporting

**Important:** Do not modify:
- `project` - Project name (set on loop creation)
- `loopName` - Loop name (matches directory)
- `branchName` - Git branch (managed by git)
- `generatedAt` - Creation timestamp (historical record)
- `sprintStatusPath` - Path to sprint YAML (set on creation)

These fields are set during loop creation and shouldn't be changed manually.

**Use Cases:**

- Adjust iteration limits for long-running loops
- Fine-tune stuck detection threshold
- Enable/disable specific quality gates
- Add project-specific instructions
- Filter to specific epic for focused work
- Reset statistics after manual fixes

**Best Practices:**

1. **Review Before Editing:** Use `ralph show <name>` to see current config
2. **Small Changes:** Make one change at a time for easier troubleshooting
3. **Test Quality Gates:** Ensure custom commands work before adding them
4. **Backup Important Loops:** Copy loop directory before major config changes
5. **Validate Manually:** Run `jq . config.json` to check syntax before running loop
6. **Document Custom Instructions:** Keep instructions clear and concise
7. **Conservative Limits:** Start with default values, adjust based on experience
