You are executing the **Ralph Init** command to initialize ralph in a BMAD project.

## Command Overview

**Purpose:** Initialize ralph autonomous loop system in the current BMAD project

**Agent:** Ralph CLI

**Output:** ralph/ directory with configuration files

---

## Execution

Run the ralph CLI init command:

```bash
ralph init
```

### Options

- `--force` - Reinitialize even if already initialized
- `--install-agent` - Install ralph agent files into project BMAD config

### What It Does

1. Creates `ralph/` directory structure
2. Detects quality gates from package.json (typecheck, test, lint, build)
3. Creates `ralph/prompt.md` template
4. Creates `ralph/prd.json.example`
5. Initializes `ralph/progress.txt`

### Prerequisites

- Must be in a BMAD project (has `bmad/config.yaml` or `docs/sprint-status.yaml`)
- ralph CLI must be available (`npm link` in packages/cli or global install)

### Next Steps

After init, run:
- `ralph create <loop-name>` to create a new loop
- `ralph config quality-gates` to configure quality gates
