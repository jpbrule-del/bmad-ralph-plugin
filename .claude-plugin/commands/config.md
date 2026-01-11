You are executing the **Ralph Config** command to manage configuration.

## Command Overview

**Purpose:** View and manage Ralph configuration settings for quality gates and loop defaults

**Agent:** Ralph CLI

**Output:** Configuration display or interactive quality gate configuration with confirmation

---

## Execution

Run the ralph CLI config command with a subcommand:

```bash
ralph config <subcommand>
```

### Subcommands

#### Show Configuration
```bash
ralph config show
```
Displays current Ralph configuration including all quality gates with their status (enabled/disabled).

#### Configure Quality Gates
```bash
ralph config quality-gates
```
Interactive configuration wizard for quality gate commands with confirmation and validation.

### Examples

```bash
# Display current configuration
ralph config show

# Configure quality gates interactively
ralph config quality-gates
```

### What It Does

#### Config Show Subcommand

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/config.yaml` or `ralph/config.json` exists)
   - Displays error if no configuration file found

2. **Identifies Configuration File**
   - Checks for `ralph/config.json` (preferred)
   - Falls back to `ralph/config.yaml` if JSON not found
   - Displays which configuration file is being used

3. **Displays Quality Gates**
   - Reads quality gate configuration from config file
   - Shows typecheck command (or "disabled" if null)
   - Shows test command (or "disabled" if null)
   - Shows lint command (or "disabled" if null)
   - Shows build command (or "disabled" if null)
   - Uses color coding: green for enabled gates, dim for disabled

4. **Provides Next Steps**
   - Shows command to modify configuration: `ralph config quality-gates`

#### Config Quality-Gates Subcommand

1. **Validates Prerequisites**
   - Checks Ralph is initialized (`ralph/config.yaml` or `ralph/config.json` exists)
   - Displays error if no configuration file found

2. **Provides Context**
   - Explains that quality gates run after each story implementation
   - Sets expectations for the interactive configuration process

3. **Prompts for Quality Gate Commands**
   - Prompts for typecheck command (e.g., `npm run typecheck` or `npx tsc --noEmit`)
   - Prompts for test command (e.g., `npm test` or `npm run test:unit`)
   - Prompts for lint command (e.g., `npm run lint` or `eslint .`)
   - Prompts for build command (e.g., `npm run build` or `tsc`)
   - Allows leaving fields empty to disable that gate
   - Uses interactive prompts from CLI's interactive.sh module

4. **Displays Configuration Summary**
   - Shows all configured quality gates in a summary view
   - Displays "disabled" for any gates left empty
   - Color-codes for easy scanning

5. **Confirms Changes**
   - Prompts user to confirm: "Save this configuration? [Y/n]:"
   - Defaults to "Yes" if user just presses Enter
   - Exits without saving if user declines

6. **Updates Configuration File**
   - For JSON files: Uses atomic write pattern with jq
     - Creates temporary file
     - Updates `.config.qualityGates` object with new values
     - Sets null for disabled gates
     - Validates JSON syntax before committing
     - Moves temp file to `ralph/config.json` on success
   - For YAML files: Uses atomic write pattern with yq
     - Creates temporary file
     - Updates `.defaults.quality_gates` object with new values
     - Sets null for disabled gates
     - Validates YAML syntax before committing
     - Moves temp file to `ralph/config.yaml` on success
   - Displays success message or error on failure

7. **Provides Important Note**
   - Reminds user that quality gates apply to new loops created after this change
   - Existing loops retain their quality gate configuration from creation time

---

## Prerequisites

Before running this command, ensure:

1. **Ralph is initialized** - Run `/bmad-ralph:init` first if not already done
2. **Configuration file exists** - `ralph/config.json` or `ralph/config.yaml` must exist
3. **Required tools installed** - For the command to work:
   - `jq` (for JSON config files)
   - `yq` v4+ (for YAML config files)

### Configuration File Locations

- **Global config:** `ralph/config.json` or `ralph/config.yaml`
  - Contains default quality gates for new loops
  - Managed by this command
- **Per-loop config:** `ralph/loops/<name>/config.json`
  - Each loop has its own quality gate configuration
  - Created at loop creation time from global defaults
  - Not affected by changes to global config after loop creation

---

## Quality Gates

Quality gates are commands that run after each story implementation to ensure code quality:

### Typecheck Gate
Runs type checking to catch type errors:
- TypeScript: `npm run typecheck` or `npx tsc --noEmit`
- Flow: `npm run flow`
- Python: `mypy .` or `pyright`

### Test Gate
Runs test suite to ensure functionality:
- Node.js: `npm test` or `npm run test:unit`
- Python: `pytest` or `python -m unittest`
- Go: `go test ./...`

### Lint Gate
Runs linter to enforce code style:
- JavaScript/TypeScript: `npm run lint` or `eslint .`
- Python: `pylint .` or `flake8`
- Go: `golangci-lint run`

### Build Gate
Runs build to ensure project compiles:
- TypeScript: `npm run build` or `tsc`
- Python: `python setup.py build`
- Go: `go build ./...`

### Disabling Quality Gates

To disable a quality gate:
1. Run `ralph config quality-gates`
2. Press Enter without typing anything when prompted for that gate
3. The gate will be set to null (disabled)

Disabling gates can be useful for:
- Fast prototyping where quality checks slow iteration
- Projects without that type of check (e.g., no TypeScript = no typecheck)
- Debugging when gates are failing incorrectly

---

## Related Commands

- `/bmad-ralph:init` - Initialize Ralph with auto-detected quality gates
- `/bmad-ralph:edit <loop-name>` - Edit loop-specific configuration
- `/bmad-ralph:create <loop-name>` - Create new loop with current quality gate defaults
- `/bmad-ralph:show <loop-name>` - Display loop configuration including quality gates

---

## Troubleshooting

### "Ralph is not initialized in this project"
**Cause:** No `ralph/config.yaml` or `ralph/config.json` file exists.

**Solution:** Run `/bmad-ralph:init` to initialize Ralph in this project first.

### "No configuration file found"
**Cause:** Ralph directory exists but config file was deleted or corrupted.

**Solution:**
1. Backup any existing `ralph/` directory
2. Re-run `/bmad-ralph:init` to recreate configuration
3. Manually restore any custom settings

### "Failed to update configuration"
**Cause:** JSON/YAML validation failed after update, or file permissions issue.

**Solution:**
1. Check the error message for syntax issues
2. Ensure you have write permissions to `ralph/` directory
3. Manually inspect `ralph/config.json` or `ralph/config.yaml` for corruption
4. Try running the command again

### Quality gates don't affect existing loops
**Cause:** Each loop has its own quality gate configuration set at creation time.

**Solution:** This is by design. To update quality gates for an existing loop:
1. Use `/bmad-ralph:edit <loop-name>` to manually edit the loop's `config.json`
2. Update the `.config.qualityGates` object with new commands
3. Or create a new loop with updated quality gates using `/bmad-ralph:create`

### Commands fail with "command not found"
**Cause:** Quality gate command doesn't exist in the project or PATH.

**Solution:**
1. Verify the command exists: run it manually first
2. Check `package.json` scripts section for available commands
3. Update quality gates with correct command names
4. Common fixes:
   - `npm run typecheck` → Ensure "typecheck" script exists in package.json
   - `npx tsc --noEmit` → Ensure TypeScript is installed as dependency

---

## Implementation Notes

### Command Flow

1. User runs `/bmad-ralph:config show` or `/bmad-ralph:config quality-gates`
2. Claude Code invokes the command handler
3. Handler runs `ralph config <subcommand>` from CLI
4. CLI validates prerequisites and executes the subcommand
5. For `show`: Displays current configuration
6. For `quality-gates`: Prompts interactively, then updates configuration file
7. Success/error message displayed to user

### Configuration File Formats

**JSON Format (`ralph/config.json`):**
```json
{
  "project": "my-project",
  "config": {
    "qualityGates": {
      "typecheck": "npm run typecheck",
      "test": "npm test",
      "lint": "npm run lint",
      "build": "npm run build"
    }
  }
}
```

**YAML Format (`ralph/config.yaml`):**
```yaml
defaults:
  quality_gates:
    typecheck: npm run typecheck
    test: npm test
    lint: npm run lint
    build: npm run build
```

### Atomic Write Pattern

The config command uses atomic writes to prevent corruption:
1. Write to temporary file
2. Validate syntax with jq/yq
3. Move temp file to final location (atomic operation)
4. Delete temp file on failure

This ensures the config file is never left in an invalid state.

### Validation

- **JSON validation:** Uses `jq . file` to validate JSON syntax
- **YAML validation:** Uses `yq . file` to validate YAML syntax
- **Command validation:** No validation of quality gate commands - they're validated at execution time
- **Null handling:** Disabled gates are stored as `null`, not empty strings

### Auto-Detection

During `ralph init`, quality gates are auto-detected from:
- `package.json` scripts (for npm/yarn/pnpm projects)
- Common files (`tsconfig.json` for TypeScript, `pytest.ini` for Python, etc.)
- User can override detected values during interactive setup

### Global vs Loop Configuration

**Global configuration** (managed by this command):
- Location: `ralph/config.json` or `ralph/config.yaml`
- Purpose: Default quality gates for new loops
- Changes: Only affect newly created loops

**Loop configuration** (per loop):
- Location: `ralph/loops/<name>/config.json`
- Purpose: Quality gates for specific loop
- Changes: Affect only that loop
- Created: Copied from global config at loop creation time
- Modified: Use `/bmad-ralph:edit <loop-name>` to change

### Backward Compatibility

- Supports both JSON and YAML configuration files
- JSON is preferred (faster parsing, better tooling)
- YAML supported for legacy compatibility
- If both exist, JSON takes precedence
