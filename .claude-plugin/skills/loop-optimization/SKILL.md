---
name: Loop Optimization
description: Analyzes Ralph loop performance and provides proactive optimization suggestions
triggers:
  - command: bmad-ralph:run
  - context: loop_running
  - condition: iteration_count > 0
auto_invoke: true
priority: medium
---

# Loop Optimization Skill

When a user runs a Ralph loop, this skill automatically analyzes loop performance patterns and provides intelligent optimization suggestions to improve efficiency, reduce stuck scenarios, and enhance quality gate performance.

## Trigger Conditions

This skill is invoked automatically during `/bmad-ralph:run` command execution when:

- **Loop is actively running** - Loop has started executing stories
- **Iteration count > 0** - At least one iteration has completed (has execution data to analyze)
- **Performance metrics available** - Can access `config.json`, `progress.txt`, and `sprint-status.yaml`
- **After story completion** - Best time to provide suggestions is after completing a story

## Performance Analysis Factors

### 1. Iteration Efficiency

Analyze iterations per story to identify potential issues:

**Metrics to Check:**
- Average iterations per story from `config.json` (`stats.averageIterationsPerStory`)
- Individual story attempts from `storyNotes` in `config.json`
- Current story iteration count from `progress.txt`

**Thresholds:**
- **Green (Optimal):** ≤ 2 iterations per story
- **Yellow (Warning):** 3-4 iterations per story
- **Red (Concern):** ≥ 5 iterations per story

**Suggested Actions:**
- If average > 3: Suggest reviewing prompt complexity or breaking down stories
- If any story > 5: Flag as potential prompt clarity issue or story scope problem
- If pattern across multiple stories: Recommend quality gate tuning

### 2. Stuck Pattern Detection

Analyze `progress.txt` for stuck indicators and failure patterns:

**Patterns to Detect:**
- **Repetitive errors** - Same error message appearing multiple times
- **Quality gate failures** - Specific gates failing consistently
- **Story abandonment** - Stories with multiple attempts but no completion
- **Timeout patterns** - Long iteration times indicating stuck detection

**Suggested Actions:**
- **Same error 3+ times:** Suggest adding explicit handling or breaking down the story
- **Lint failures repeatedly:** Recommend running `npm run lint:fix` or adjusting lint rules
- **Build failures repeatedly:** Suggest reviewing build configuration or dependencies
- **Test failures repeatedly:** Recommend running tests locally first or adjusting test strategy

### 3. Quality Gate Performance

Track quality gate pass/fail rates to optimize configuration:

**Metrics to Check:**
- Quality gate configuration from `config.json` (`config.qualityGates`)
- Gate execution results from `progress.txt`
- Gate failure patterns across stories

**Optimization Recommendations:**

**If lint gate failing often:**
- Consider running `npm run lint:fix` automatically before commit
- Review lint rules for overly strict or conflicting rules
- Suggest adding `.eslintignore` for generated files

**If typecheck gate failing often:**
- Recommend running `npx tsc --noEmit` during development
- Suggest reviewing TypeScript configuration (`tsconfig.json`)
- Consider incremental type checking with `--incremental` flag

**If test gate failing often:**
- Suggest running tests locally before commits
- Recommend reviewing test coverage requirements
- Consider adding `--bail` flag to fail fast on first error

**If build gate failing often:**
- Review build configuration for missing dependencies
- Suggest checking for environment-specific build issues
- Consider caching build artifacts between iterations

### 4. Iteration Threshold Recommendations

Analyze stuck threshold configuration effectiveness:

**Current Threshold:** Check `config.stuck_threshold` (default: 3)

**Recommendation Logic:**
- **If many stories complete in 1-2 iterations:** Threshold is appropriate, no change needed
- **If many stories hit threshold (3 attempts):** Consider increasing to 4-5 for more complex work
- **If stories rarely exceed 2 iterations:** Consider lowering threshold to 2 for faster stuck detection
- **If pattern varies by epic:** Suggest creating separate loops with different thresholds per epic

### 5. Prompt Improvement Suggestions

Analyze loop prompt effectiveness based on stuck patterns:

**Indicators of Prompt Issues:**
- Stories consistently misunderstood (wrong files modified)
- Repeated questions about architecture or patterns
- Quality gates failing due to style/convention violations
- Agent making same mistakes across multiple stories

**Suggested Prompt Improvements:**

**If architecture confusion:**
```markdown
Add to custom instructions:
- Explicit file structure map
- Component responsibility boundaries
- Import path conventions
```

**If style violations:**
```markdown
Add to custom instructions:
- Coding style preferences
- Naming conventions
- Comment requirements
```

**If quality gate misunderstanding:**
```markdown
Add to custom instructions:
- Quality gate expectations
- How to run gates locally
- Acceptable gate failure scenarios
```

**If story scope confusion:**
```markdown
Add to custom instructions:
- Story size guidelines
- Acceptance criteria format
- Definition of "done"
```

## Proactive Suggestions

Offer suggestions automatically when these conditions are met:

### During Loop Execution

**Trigger:** Story takes > 3 iterations
```
⚠️  Loop Optimization Suggestion:

This story has taken 4 iterations so far. Consider:
1. Breaking down the story into smaller subtasks
2. Adding more specific acceptance criteria
3. Reviewing custom instructions for clarity

Would you like me to analyze the stuck patterns in progress.txt?
```

**Trigger:** Same error appears 3+ times
```
🔍 Loop Optimization Suggestion:

The error "[error message]" has appeared 3 times. Consider:
1. Adding explicit error handling for this scenario
2. Updating story requirements to address this case
3. Modifying quality gates to catch this earlier

Recent occurrences:
- Iteration 5: [brief context]
- Iteration 7: [brief context]
- Iteration 9: [brief context]
```

**Trigger:** Quality gate fails repeatedly (3+ times)
```
🛠️  Loop Optimization Suggestion:

The [gate name] quality gate has failed 4 times. Consider:
1. Running `[gate command]` locally before commits
2. Adjusting gate configuration in ralph/config.yaml
3. Reviewing gate requirements for this project

Recent failures:
- STORY-XXX: [failure reason]
- STORY-YYY: [failure reason]
```

### After Loop Completion

**Trigger:** Loop completes all stories
```
✅ Loop Optimization Report:

Loop completed successfully! Here's what we learned:

Performance Summary:
- Total iterations: 25
- Stories completed: 10
- Average iterations/story: 2.5
- Quality gate pass rate: 92%

Recommendations for future loops:
1. [Top recommendation based on metrics]
2. [Second recommendation]
3. [Third recommendation]

Great work! Consider archiving this loop with feedback.
```

## Implementation Notes

**Data Sources:**
- `ralph/loops/<name>/config.json` - Execution statistics, quality gates, thresholds
- `ralph/loops/<name>/progress.txt` - Iteration log, error patterns, completion notes
- `docs/sprint-status.yaml` - Story definitions, point values, acceptance criteria
- `.git/logs/refs/heads/ralph/<name>` - Commit history, timestamps

**Analysis Timing:**
- **Light analysis:** After each story completion (quick metrics check)
- **Deep analysis:** Every 5 iterations or when stuck threshold is hit
- **Summary analysis:** On loop completion or pause

**Presentation:**
- Use clear emoji indicators (⚠️ 🔍 🛠️ ✅)
- Keep suggestions concise (3-5 bullet points max)
- Provide actionable next steps
- Include relevant data excerpts for context

**Safety:**
- Never block loop execution with suggestions
- Suggestions are advisory only, not prescriptive
- User can dismiss or ignore any suggestion
- Don't suggest destructive changes (deleting stories, etc.)

## Related Commands

- `/bmad-ralph:run` - This skill triggers during run command
- `/bmad-ralph:status` - Check current metrics that inform analysis
- `/bmad-ralph:show` - View detailed statistics used for recommendations
- `/bmad-ralph:config quality-gates` - Adjust gates based on recommendations
- `/bmad-ralph:edit` - Modify loop configuration per suggestions

## Troubleshooting

**Skill not triggering:**
- Verify loop is running (`ralph/loops/<name>/.lock` file exists)
- Check that iteration count > 0 (at least one story attempted)
- Ensure skill directory and SKILL.md exist in plugin

**Suggestions not helpful:**
- Skill learns from available data - more iterations = better suggestions
- Early in loop execution, suggestions may be generic
- Provide feedback via `ralph archive` to improve future analysis

**Too many suggestions:**
- Skill triggers are designed to be non-intrusive
- Suggestions only appear at natural breakpoints (story completion)
- User can safely ignore suggestions that don't apply

## Example Analysis Session

```
User: ralph run my-sprint

Ralph: Starting loop 'my-sprint' (5 stories remaining)...

[After STORY-003 completes with 4 iterations]

🔍 Loop Optimization Suggestion:

STORY-003 took 4 iterations (above average of 2.1). Analysis shows:
- Lint gate failed 3 times with "missing semicolon" errors
- Suggestion: Run `npm run lint:fix` after implementation, before commit

[After STORY-005 completes]

✅ Loop running efficiently:
- Average iterations/story: 2.2
- Quality gate pass rate: 95%
- On track to complete all stories

Keep up the great work! No optimizations needed at this time.
```
