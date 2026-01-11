You are executing the **Ralph Feedback Report** command to view analytics.

## Command Overview

**Purpose:** Generate aggregate feedback analytics across all archived loops

**Agent:** Ralph CLI

**Output:** Feedback summary with statistics and themes

---

## Execution

Run the ralph CLI feedback-report command:

```bash
ralph feedback-report
```

### Options

- `--json` - Output in JSON format

### Report Contents

- **Satisfaction Scores**
  - Average satisfaction (1-5 scale)
  - Distribution by score
  - Trend over time

- **Success Metrics**
  - Total loops archived
  - Average stories completed per loop
  - Average iterations per story

- **Common Themes**
  - What worked well (aggregated)
  - Areas for improvement (aggregated)
  - Reusability preferences

### Data Source

Reads from all `feedback.json` files in `ralph/archive/*/`

### Use Cases

- Identify patterns in successful configurations
- Find recurring issues to address
- Track improvement over time
- Make data-driven decisions about quality gates

### Related Commands

- `ralph archive <name>` - Archive with feedback
- `ralph list --archived` - See archived loops
