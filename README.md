# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop for **Claude Code**. It runs Claude Code CLI repeatedly until all PRD items are complete. Each iteration is a fresh Claude session with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

## Quick Start

```bash
# Initialize Ralph in your project
npx @ralph/cli init

# Configure your stories in ralph/prd.json
# Then run the autonomous loop
npx @ralph/cli run
```

Or install as a Claude Code command:

```bash
npx @ralph/cli install
# Then use /ralph in Claude Code
```

## Prerequisites

- [Claude Code CLI](https://claude.ai/claude-code) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## Installation Options

### Option 1: npx (Recommended)

Zero install required. Run directly:

```bash
npx @ralph/cli init    # Initialize in your project
npx @ralph/cli run     # Run the loop
npx @ralph/cli status  # Check progress
```

### Option 2: Global Install

```bash
npm install -g @ralph/cli
ralph init
ralph run
```

### Option 3: Claude Code Command

Install as a slash command:

```bash
npx @ralph/cli install
```

Then use `/ralph` directly in Claude Code.

## Workflow

### 1. Initialize Ralph

```bash
npx @ralph/cli init
```

This creates a `ralph/` directory with:
- `prompt.md` - Instructions for each Claude iteration
- `prd.json.example` - Template for your stories
- `progress.txt` - Iteration log

### 2. Configure Your Stories

Copy `prd.json.example` to `prd.json` and add your user stories:

```json
{
  "project": "my-feature",
  "branchName": "ralph/my-feature",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add user profile page",
      "description": "Create a profile page showing user details",
      "acceptanceCriteria": [
        "Profile page renders at /profile",
        "Shows user name and email",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "attempts": 0
    }
  ]
}
```

### 3. Run Ralph

```bash
npx @ralph/cli run
```

Ralph will:
1. Pick the highest priority story where `passes: false`
2. Implement that single story
3. Run quality gates (typecheck, tests)
4. Commit if gates pass
5. Update `prd.json` to mark story as `passes: true`
6. Append learnings to `progress.txt`
7. Repeat until all stories pass

## Key Concepts

### Fresh Context Per Iteration

Each iteration spawns a **new Claude Code session** with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each story should be small enough to complete in one context window:

**Right-sized stories:**
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

**Too big (split these):**
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### Quality Gates

Configure quality gates in your `prd.json`:

```json
{
  "config": {
    "qualityGates": {
      "typecheck": "npm run typecheck",
      "test": "npm test",
      "lint": "npm run lint"
    }
  }
}
```

All gates must pass before a commit is made.

### Template Customization

Ralph uses templates to generate loop files (`loop.sh` and `prompt.md`). You can customize these templates by creating your own versions:

1. Create a `ralph/templates/` directory in your project
2. Add custom templates with these filenames:
   - `loop.sh.template` - Custom loop orchestration script template
   - `prompt.md.template` - Custom Claude Code context prompt template

Ralph will automatically use your custom templates if they exist, falling back to the defaults if not.

**Template Variables:**

Templates use `{{VARIABLE_NAME}}` placeholders that get replaced during generation:

**loop.sh.template:**
- `{{TIMESTAMP}}` - ISO 8601 timestamp
- `{{PROJECT_NAME}}` - Project name from sprint-status.yaml
- `{{BRANCH_NAME}}` - Current git branch
- `{{MAX_ITERATIONS}}` - Maximum iterations configured
- `{{STUCK_THRESHOLD}}` - Stuck detection threshold
- `{{SPRINT_STATUS_FILE}}` - Path to sprint-status.yaml
- `{{TYPECHECK_CMD}}`, `{{TEST_CMD}}`, `{{LINT_CMD}}`, `{{BUILD_CMD}}` - Quality gate commands

**prompt.md.template:**
- `{{PROJECT_NAME}}` - Project name
- `{{SPRINT_GOAL}}` - Sprint goal from sprint-status.yaml
- `{{BRANCH_NAME}}` - Current git branch
- `{{SPRINT_STATUS_PATH}}` - Path to sprint-status.yaml
- `{{ARCHITECTURE_PATTERNS}}` - Auto-detected architecture docs reference
- `{{QUALITY_GATES}}` - Formatted quality gates list
- `{{EPIC_CONTEXT}}` - Epic filter context

Example:
```bash
mkdir -p ralph/templates
cp packages/cli/templates/prompt.md.template ralph/templates/
# Edit ralph/templates/prompt.md.template with your customizations
```

### AGENTS.md Updates

After each iteration, Ralph updates `AGENTS.md` with discovered patterns. Claude Code automatically reads these files, so future iterations benefit from learnings.

## Project Structure

```
ralph/                    # Monorepo root
├── packages/
│   ├── cli/              # npm-installable CLI (@ralph/cli)
│   ├── core/             # Core bash scripts
│   └── skills/           # Claude Code commands
├── apps/
│   └── flowchart/        # Interactive visualization
└── docs/                 # Documentation
```

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

To run locally:

```bash
cd apps/flowchart
npm install
npm run dev
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `ralph init` | Initialize Ralph in your project |
| `ralph run` | Run the autonomous loop |
| `ralph status` | Show current progress |
| `ralph install` | Install as Claude Code command |

## Signals

Ralph uses these signals for loop control:

| Signal | Meaning |
|--------|---------|
| `<complete>ALL_STORIES_PASSED</complete>` | All done, exit success |
| `<stuck>STORY_ID: reason</stuck>` | Cannot complete, increment attempts |

## Debugging

```bash
# Check progress
npx @ralph/cli status

# See which stories are done
cat ralph/prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat ralph/progress.txt

# Check git history
git log --oneline -10
```

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://claude.ai/claude-code)
