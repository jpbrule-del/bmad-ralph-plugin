You are executing the **Ralph Config** command to manage configuration.

## Command Overview

**Purpose:** View and manage ralph configuration settings

**Agent:** Ralph CLI

**Output:** Configuration display or interactive configuration

---

## Execution

Run the ralph CLI config command:

```bash
ralph config <subcommand>
```

### Subcommands

#### Show Configuration
```bash
ralph config show
```
Displays current configuration including:
- Quality gates (commands for typecheck, test, lint, build)
- Default loop parameters
- BMAD integration settings

#### Configure Quality Gates
```bash
ralph config quality-gates
```
Interactive configuration for quality gate commands:
- Typecheck command (e.g., `npm run typecheck`)
- Test command (e.g., `npm test`)
- Lint command (e.g., `npm run lint`)
- Build command (e.g., `npm run build`)

### Configuration Files

- **Global:** `ralph/config.yaml`
- **Per-loop:** `ralph/loops/<name>/prd.json`

### Auto-Detection

When initializing, ralph auto-detects quality gates from:
- `package.json` scripts
- Common patterns (tsconfig.json for TypeScript, etc.)

### Related Commands

- `ralph init` - Initialize ralph with auto-detected config
- `ralph edit <loop-name>` - Edit specific loop configuration
