# /bmad-ralph:feedback-report

Generate aggregate feedback analytics from archived Ralph loops to analyze patterns, satisfaction trends, and areas for improvement.

## Overview

The `feedback-report` command analyzes all archived loops with feedback data to provide insights into Ralph's effectiveness across your project history. It aggregates satisfaction scores, success rates, manual intervention patterns, and qualitative feedback themes to help you understand what's working and what needs improvement.

## Execution

When the user invokes `/bmad-ralph:feedback-report`, execute:

```bash
ralph feedback-report
```

For JSON output format:

```bash
ralph feedback-report --json
```

## What It Does

1. **Scans Archive Directory**: Searches `ralph/archive/` for all archived loops with `feedback.json` files
2. **Aggregates Metrics**: Collects satisfaction scores, would-run-again responses, manual intervention counts, and loop statistics
3. **Calculates Analytics**:
   - Average satisfaction score (1-5 scale)
   - Satisfaction distribution (count per rating)
   - Success rate (percentage who would run config again)
   - Manual intervention rate (fixes required per story)
4. **Themes Analysis**: Aggregates common patterns from qualitative feedback (what worked well, what should improve)
5. **Displays Report**: Shows comprehensive analytics with color-coded metrics and actionable insights

## Prerequisites

- Ralph must be initialized (`ralph/` directory exists)
- At least one archived loop with feedback data (`ralph archive <name>` collects feedback)

## Output Format

### Human-Readable Report

```
╔════════════════════════════════════════════════════════════╗
║ Feedback Analytics Report
╚════════════════════════════════════════════════════════════╝

ℹ Overview
  Archived loops analyzed:  5
  Total stories completed:  42
  Total iterations run:     75

╔════════════════════════════════════════════════════════════╗
║ Satisfaction Metrics
╚════════════════════════════════════════════════════════════╝

  Average satisfaction:     4.20/5.0 ✓

  Satisfaction distribution:
    5 ⭐: ████████████ 3 (60%)
    4 ⭐: ████ 1 (20%)
    3 ⭐: ████ 1 (20%)

╔════════════════════════════════════════════════════════════╗
║ Success Rate
╚════════════════════════════════════════════════════════════╝

  Would run config again:   80.0% ✓
  Yes: 4  |  No: 1

╔════════════════════════════════════════════════════════════╗
║ Manual Interventions
╚════════════════════════════════════════════════════════════╝

  Total manual fixes:       8 stories
  Intervention rate:        19.0%

╔════════════════════════════════════════════════════════════╗
║ Feedback Themes
╚════════════════════════════════════════════════════════════╝

✓ What Worked Well (4 responses):

  1. Quality gates caught most issues before commit
  2. Progress tracking helped me understand loop state
  3. Automatic branch management saved time
  4. Stuck detection prevented infinite loops

⚠ What Should Improve (3 responses):

  1. Better error messages when quality gates fail
  2. More granular control over retry behavior
  3. Support for custom quality gate configurations

ℹ Run 'ralph show <loop-name>' to view detailed feedback for specific loops
```

### JSON Output

```json
{
  "archivedLoops": 5,
  "analytics": {
    "averageSatisfaction": "4.20",
    "totalFeedback": 5,
    "successRate": "80.0",
    "wouldRunAgain": {
      "yes": 4,
      "no": 1
    },
    "totalStoriesCompleted": 42,
    "totalIterations": 75,
    "manualInterventions": 8,
    "themes": {
      "workedWell": [
        "Quality gates caught most issues before commit",
        "Progress tracking helped me understand loop state",
        "Automatic branch management saved time",
        "Stuck detection prevented infinite loops"
      ],
      "shouldImprove": [
        "Better error messages when quality gates fail",
        "More granular control over retry behavior",
        "Support for custom quality gate configurations"
      ]
    }
  }
}
```

## Related Commands

- `/bmad-ralph:archive <name>` - Archive a loop and collect feedback
- `/bmad-ralph:show <name>` - View detailed feedback for a specific archived loop
- `/bmad-ralph:list --archived` - List all archived loops

## Troubleshooting

### No Archived Loops Found

If you see "No archived loops found":
- Archive at least one completed loop using `/bmad-ralph:archive <name>`
- Ensure `ralph/archive/` directory exists

### No Feedback Data

If archived loops exist but no feedback is shown:
- Feedback is collected during the archive process
- Re-archive loops without using `--skip-feedback` flag
- Ensure feedback questionnaire was completed during archiving

### Empty Themes Section

If themes section is empty:
- Users may have skipped qualitative questions during archiving
- Consider providing more specific prompts during feedback collection

## Metrics Interpretation

### Satisfaction Score
- **4.0-5.0**: Excellent - configuration working very well
- **3.0-3.9**: Good - minor improvements needed
- **Below 3.0**: Needs attention - review common themes for issues

### Success Rate (Would Run Again)
- **≥75%**: Strong confidence in configuration
- **50-74%**: Mixed results - investigate specific pain points
- **<50%**: Configuration needs significant refinement

### Manual Intervention Rate
- **<10%**: Excellent autonomy
- **10-25%**: Normal - expected for complex tasks
- **>25%**: High - consider quality gate tuning or simpler stories

## Implementation Notes

For Claude:

1. **Command Invocation**:
   - Always use the `ralph` CLI directly
   - Pass `--json` flag when machine-readable output is needed
   - Handle both success and no-data scenarios gracefully

2. **Data Sources**:
   - Scans `ralph/archive/*/feedback.json` files
   - Each feedback file contains loop statistics and user responses
   - Missing feedback files are silently skipped

3. **Calculations**:
   - Average satisfaction: Mean of all satisfaction scores (1-5)
   - Success rate: Percentage of "yes" responses to "would run again"
   - Intervention rate: Manual interventions ÷ total stories completed
   - Distribution: Count of each satisfaction score

4. **Themes Aggregation**:
   - Collects all "worked well" and "should improve" text responses
   - Displays up to 100 characters per response (truncated with "...")
   - Provides raw full text in JSON output

5. **Use Cases**:
   - **Periodic Review**: Run monthly to track Ralph effectiveness over time
   - **Configuration Tuning**: Identify common improvement themes to adjust quality gates
   - **Success Validation**: Confirm high satisfaction before expanding Ralph usage
   - **Pattern Detection**: Spot systematic issues across multiple loops

6. **Integration**:
   - Combine with `/bmad-ralph:show <name>` to drill into specific loop feedback
   - Use `--json` output for automated reporting or dashboards
   - Compare metrics before/after configuration changes
