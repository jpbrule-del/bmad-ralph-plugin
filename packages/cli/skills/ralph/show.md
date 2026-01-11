You are executing the **Ralph Show** command to display loop details.

## Command Overview

**Purpose:** Display detailed information about a specific loop

**Agent:** Ralph CLI

**Output:** Comprehensive loop information including configuration, stats, and progress

---

## Execution

Run the ralph CLI show command:

```bash
ralph show <loop-name>
```

### Options

- `--json` - Output in JSON format

### Examples

```bash
# Show loop details
ralph show sprint-2

# Get JSON output
ralph show sprint-2 --json
```

### Information Displayed

- **Configuration**
  - Max iterations
  - Stuck threshold
  - Quality gates (enabled commands)
  - Epic filter (if set)

- **Execution Statistics**
  - Total iterations run
  - Stories completed
  - Start/end timestamps
  - Average iterations per story

- **Story Progress**
  - List of stories with status
  - Attempt counts
  - Completion timestamps

- **Git Information**
  - Branch name
  - Commit count

### Related Commands

- `ralph list` - List all loops
- `ralph edit <name>` - Edit loop configuration
