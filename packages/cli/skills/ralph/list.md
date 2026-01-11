You are executing the **Ralph List** command to show all loops.

## Command Overview

**Purpose:** List all loops in the project with their status and progress

**Agent:** Ralph CLI

**Output:** Table of loops with status information

---

## Execution

Run the ralph CLI list command:

```bash
ralph list
```

### Options

- `--active` - Show only active loops
- `--archived` - Show only archived loops
- `--json` - Output in JSON format

### Examples

```bash
# List all loops
ralph list

# List only active loops
ralph list --active

# List archived loops
ralph list --archived

# Get JSON output for scripting
ralph list --json
```

### Output Columns

- **Name** - Loop name
- **Status** - active/archived
- **Stories** - completed/total count
- **Created** - Creation date
- **Last Activity** - Most recent execution

### Related Commands

- `ralph show <name>` - Detailed info about a specific loop
- `ralph create <name>` - Create a new loop
- `ralph archive <name>` - Archive a completed loop
