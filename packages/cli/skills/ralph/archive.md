You are executing the **Ralph Archive** command to archive a completed loop.

## Command Overview

**Purpose:** Archive a loop with mandatory feedback collection

**Agent:** Ralph CLI

**Output:** Loop moved to `ralph/archive/<date>-<name>/` with feedback.json

---

## Execution

Run the ralph CLI archive command:

```bash
ralph archive <loop-name>
```

### Options

- `--skip-feedback` - Skip feedback collection (not recommended, for testing only)

### Feedback Questionnaire

Before archiving, you must complete:

1. **Overall satisfaction** (1-5 scale)
2. **Stories requiring manual intervention** (count)
3. **What worked well?** (required text)
4. **What should be improved?** (required text)
5. **Would you run this config again?** (yes/no)

### What It Does

1. Collects mandatory feedback
2. Creates `ralph/archive/<YYYY-MM-DD>-<loop-name>/`
3. Moves all loop files to archive
4. Creates `feedback.json` with responses
5. Preserves execution statistics

### Archive Structure

```
ralph/archive/2026-01-11-sprint-2/
├── prd.json
├── prompt.md
├── loop.sh
├── progress.txt
└── feedback.json
```

### Related Commands

- `ralph unarchive <name>` - Restore from archive
- `ralph list --archived` - List archived loops
- `ralph feedback-report` - View aggregate feedback analytics
