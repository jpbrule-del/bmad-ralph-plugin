You are executing the **Ralph Init** command to initialize Ralph in a BMAD project.

## Command Overview

**Purpose:** Initialize Ralph autonomous loop system in the current BMAD project

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
- `--install-agent` - Install Ralph agent files into project BMAD config

### Examples

```bash
# Basic initialization
ralph init

# Force reinitialize (overwrites existing config)
ralph init --force

# Initialize with BMAD agent integration
ralph init --install-agent

# Force reinitialize with agent
ralph init --force --install-agent
```

### What It Does

1. **Validates BMAD Project**
   - Checks for `docs/sprint-status.yaml` or `bmad/config.yaml`
   - Exits with error if not a BMAD project

2. **Creates Directory Structure**
   - Creates `ralph/loops/` - Storage for automation loops
   - Creates `ralph/archive/` - Storage for archived loops

3. **Generates Configuration**
   - Creates `ralph/config.yaml` with:
     - Project metadata (name, paths)
     - Default settings (max_iterations: 50, stuck_threshold: 3)
     - Quality gate configuration (lint, test, typecheck, build)
   - Auto-detects BMAD paths from project structure

4. **Installs Agent Files** (with --install-agent)
   - Creates `bmm/agents/ralph.md` - Ralph agent definition
   - Creates or updates `docs/bmm-workflow-status.yaml` - Workflow registration
   - Registers Ralph as Phase 5 (Autonomous Execution) workflow

### Prerequisites

- Must be in a BMAD project (has `docs/sprint-status.yaml` or `bmad/config.yaml`)
- Ralph CLI must be available (installed globally or via npm link)
- For `--install-agent`: Project should follow BMAD Method structure

### Quality Gates Detection

Ralph automatically detects quality gates from `package.json`:

- `npm run typecheck` or `npm run type-check` → typecheck gate
- `npm test` → test gate
- `npm run lint` → lint gate
- `npm run build` → build gate

These are configured with defaults in `ralph/config.yaml` and can be customized per loop.

### Next Steps

After initialization:

1. **Review Configuration**
   ```bash
   cat ralph/config.yaml
   # Adjust max_iterations, stuck_threshold, or quality_gates if needed
   ```

2. **Create Your First Loop**
   ```bash
   ralph create my-sprint
   # Reads stories from docs/sprint-status.yaml
   ```

3. **Run the Loop**
   ```bash
   ralph run my-sprint
   # Executes stories autonomously
   ```

4. **Monitor Progress**
   ```bash
   ralph status my-sprint
   # Watch real-time execution
   ```

### Related Commands

- `ralph config show` - Display current configuration
- `ralph config quality-gates` - Configure quality gates interactively
- `ralph create <name>` - Create a new automation loop
- `ralph list` - List all loops

### Troubleshooting

**Error: "Not a BMAD project"**
- Ensure either `docs/sprint-status.yaml` or `bmad/config.yaml` exists
- Initialize BMAD first, then run `ralph init`

**Error: "Ralph already initialized"**
- Use `ralph init --force` to reinitialize
- Or manually edit `ralph/config.yaml` if you just need configuration changes

**No quality gates detected**
- Add scripts to `package.json`: `typecheck`, `test`, `lint`, `build`
- Or manually configure in `ralph/config.yaml`

---

## Implementation Notes

This command wraps the existing bash implementation at `packages/cli/lib/commands/init.sh`. All validation, directory creation, and configuration generation logic is handled by the CLI.

The plugin command simply invokes the CLI with appropriate flags, ensuring consistent behavior between CLI and plugin usage.
