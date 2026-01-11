# Hook Execution Engine

The Hook Execution Engine is a robust system for managing and executing lifecycle hooks in the BMAD Ralph Plugin.

## Overview

The hook system provides automated event handling throughout the plugin lifecycle, including:

- **Initialization**: Plugin load, dependency verification, configuration validation
- **Pre/Post Operations**: Command execution, git commits, story completion
- **Lifecycle Events**: Loop start, pause, resume, completion
- **Monitoring**: Iteration milestones, quality gate failures, stuck detection

## Architecture

The system consists of three main components:

1. **hooks.json**: Configuration defining all hook types, execution policies, and registered hooks
2. **hook-executor.sh**: Execution engine that orchestrates hook invocation
3. **Hook Scripts**: Individual scripts that implement specific hook behaviors

## Using the Hook Executor

### Basic Commands

```bash
# Execute hooks synchronously
./hook-executor.sh execute <hook_type> [args...]

# Execute hooks asynchronously (background)
./hook-executor.sh execute-async <hook_type> [args...]

# List all registered hooks
./hook-executor.sh list

# List all hook types
./hook-executor.sh list-types

# Validate hooks.json configuration
./hook-executor.sh validate

# View recent hook execution logs
./hook-executor.sh logs [lines]
```

### Examples

```bash
# Execute plugin-load hooks
./hook-executor.sh execute plugin-load

# Execute pre-commit hooks before git commit
./hook-executor.sh execute pre-commit

# Execute post-story hooks with context
./hook-executor.sh execute post-story STORY-001 completed

# Execute hooks asynchronously
./hook-executor.sh execute-async post-command bmad-ralph:run

# View last 100 log lines
./hook-executor.sh logs 100
```

## Hook Types

| Type | Phase | Description | Can Block |
|------|-------|-------------|-----------|
| `plugin-load` | initialization | Executed when plugin loads | No |
| `pre-commit` | pre-operation | Before git commit | Yes |
| `post-commit` | post-operation | After git commit | No |
| `post-command` | post-operation | After command completion | No |
| `post-story` | post-operation | After story completion | No |
| `loop-start` | lifecycle | When loop begins | No |
| `loop-pause` | lifecycle | When loop pauses | No |
| `loop-resume` | lifecycle | When loop resumes | No |
| `loop-complete` | lifecycle | When loop completes | No |
| `iteration-milestone` | monitoring | At iteration milestones | No |
| `quality-gate-failure` | error-handling | When quality gates fail | No |
| `stuck-detection` | error-handling | When stuck detected | No |

## Hook Configuration

Each hook in `hooks.json` has the following structure:

```json
{
  "type": "post-story",
  "name": "post-story-update",
  "description": "Update progress after story completion",
  "script": "./post-story-update.sh",
  "timeout": 10000,
  "required": true,
  "on_failure": "warn",
  "execution_order": 1,
  "enabled": true,
  "args": ["arg1", "arg2"],
  "triggers": {
    "threshold": 3
  }
}
```

### Configuration Fields

- **type**: Hook type from `hook_types` registry
- **name**: Unique identifier for the hook
- **description**: Human-readable description
- **script**: Path to hook script (relative to hooks directory)
- **timeout**: Maximum execution time in milliseconds
- **required**: Whether hook is required (affects failure handling)
- **on_failure**: Failure handling strategy (`block`, `warn`, or `continue`)
- **execution_order**: Numeric order for execution (lower runs first)
- **enabled**: Whether hook is active (default: true)
- **args**: Additional arguments passed to hook script (optional)
- **triggers**: Hook-specific trigger configuration (optional)

## Execution Behavior

### Sequential Execution

Hooks with `execution_order: "sequential"` run one at a time, in order:

1. Hooks are sorted by `execution_order` field (lowest first)
2. Each hook runs to completion before the next starts
3. If a blocking hook fails, execution stops immediately
4. Non-blocking hooks continue regardless of failures

### Parallel Execution

Hooks with `execution_order: "parallel"` run concurrently:

1. Multiple hooks start simultaneously
2. Concurrency limited by `max_concurrent_hooks` (default: 3)
3. Execution waits for all hooks to complete
4. Failures are collected and reported at the end

### Async Execution

The `execute-async` command runs hooks in the background:

1. Hook execution starts in a subprocess
2. Control returns immediately to caller
3. Hooks run independently of main process
4. Completion/failure logged asynchronously

## Timeout Handling

Hooks have configurable timeout limits:

- Default timeout from `hook_types` configuration
- Override with hook-specific `timeout` field
- Global maximum from `execution_config.global_timeout`
- Timeout uses `timeout` command (or `gtimeout` on macOS)
- Timeout treated as failure, handled by `on_failure` policy

## Failure Handling

Three failure handling strategies:

### Block

```json
"on_failure": "block"
```

- Stops hook chain execution immediately
- Returns error exit code
- Used for critical hooks (pre-commit, required dependencies)

### Warn

```json
"on_failure": "warn"
```

- Logs warning but continues execution
- Returns success exit code
- Used for non-critical hooks (notifications, optional features)

### Continue

```json
"on_failure": "continue"
```

- Silently continues execution
- Returns success exit code
- Used for best-effort hooks

## Logging

All hook executions are logged to `.ralph-cache/hooks.log`:

```
[2026-01-11T09:00:00Z] HOOK_EXECUTION
  Type: pre-commit
  Name: pre-commit-quality-gates
  Status: success
  Duration: 1234ms
  Message: Completed successfully
```

### Log Levels

- **INFO**: General information (hook start, hook dispatched)
- **SUCCESS**: Hook completed successfully
- **WARN**: Hook failed but execution continues
- **ERROR**: Hook failed and may block execution

### Viewing Logs

```bash
# Last 50 lines (default)
./hook-executor.sh logs

# Last 100 lines
./hook-executor.sh logs 100

# Tail logs in real-time
tail -f .ralph-cache/hooks.log
```

## Creating Custom Hooks

### 1. Create Hook Script

```bash
#!/usr/bin/env bash
# Custom hook implementation

# Parse arguments
CONTEXT_ARG="${1:-}"

# Hook logic here
echo "Executing custom hook with: $CONTEXT_ARG"

# Exit 0 for success, non-zero for failure
exit 0
```

### 2. Register in hooks.json

```json
{
  "type": "post-story",
  "name": "my-custom-hook",
  "description": "My custom hook",
  "script": "./my-custom-hook.sh",
  "timeout": 5000,
  "required": false,
  "on_failure": "warn",
  "execution_order": 10,
  "enabled": true
}
```

### 3. Make Executable

```bash
chmod +x .claude-plugin/hooks/my-custom-hook.sh
```

### 4. Test

```bash
./hook-executor.sh execute post-story test-arg
```

## Environment Variables

### RALPH_CACHE_DIR

Override default cache directory:

```bash
export RALPH_CACHE_DIR="/custom/path/.ralph-cache"
./hook-executor.sh execute plugin-load
```

### Hook-Specific Variables

Individual hooks may support additional environment variables:

- **RALPH_BYPASS_HOOKS**: Skip pre-commit hooks (emergency bypass)
- **RALPH_NOTIFICATION_WEBHOOK**: Webhook URL for notifications
- **RALPH_AUTO_PICKUP_NEXT**: Auto-pickup next story after completion
- **RALPH_CUSTOM_LOOP_***: Custom scripts for loop lifecycle events

See individual hook documentation for details.

## Troubleshooting

### Hook Script Not Found

```
ERROR: Hook script not found: ./my-hook.sh
```

**Solution**: Verify script path is relative to hooks directory and file exists.

### Hook Script Not Executable

```
WARN: Hook script not executable, attempting to make executable: ./my-hook.sh
```

**Solution**: Run `chmod +x .claude-plugin/hooks/my-hook.sh`

### Hook Timeout

```
ERROR: Hook timed out: my-hook (timeout: 5000ms)
```

**Solution**:
- Increase timeout in hooks.json
- Optimize hook script performance
- Use async execution for long-running hooks

### Invalid Hook Type

```
ERROR: Unknown hook type: my-invalid-type
```

**Solution**: Use valid hook type from `hook_types` registry or add new type.

### Hook Failure Blocks Execution

```
ERROR: Hook failure blocks execution (on_failure=block)
```

**Solution**:
- Fix hook script error
- Change `on_failure` to `warn` if non-critical
- Use `RALPH_BYPASS_HOOKS=1` for emergency bypass (pre-commit only)

### Missing jq

```
ERROR: jq is required but not installed
```

**Solution**: Install jq:
- macOS: `brew install jq`
- Ubuntu: `apt-get install jq`
- Fedora: `dnf install jq`

## Best Practices

1. **Keep Hooks Fast**: Hooks should complete quickly (< 5s typical, < 30s maximum)
2. **Use Async for Long Operations**: Use `execute-async` for operations > 10s
3. **Handle Failures Gracefully**: Use `on_failure: "warn"` for non-critical hooks
4. **Log Liberally**: Use hook logging for debugging and auditing
5. **Test Hooks Independently**: Test hooks before enabling in production
6. **Document Custom Hooks**: Add clear comments and documentation
7. **Version Hook Configurations**: Track hooks.json changes in git
8. **Monitor Hook Performance**: Review logs regularly for slow/failing hooks

## Integration with Ralph

The hook executor integrates with Ralph loop execution:

### Plugin Load

```bash
# Called by Claude Code on plugin initialization
./hook-executor.sh execute plugin-load
```

### Pre-Commit

```bash
# Called by git pre-commit hook or Ralph commit logic
./hook-executor.sh execute pre-commit
```

### Post-Story

```bash
# Called after story completion in loop.sh
./hook-executor.sh execute post-story "$STORY_ID" "completed"
```

### Loop Lifecycle

```bash
# Loop start
./hook-executor.sh execute loop-start "$LOOP_NAME"

# Loop pause
./hook-executor.sh execute loop-pause "$LOOP_NAME"

# Loop resume
./hook-executor.sh execute loop-resume "$LOOP_NAME"

# Loop complete
./hook-executor.sh execute loop-complete "$LOOP_NAME"
```

## API Reference

### execute

Execute hooks synchronously for specified type.

```bash
./hook-executor.sh execute <hook_type> [args...]
```

**Arguments**:
- `hook_type`: Hook type from registry
- `args`: Additional arguments passed to hook scripts

**Returns**:
- 0 if all hooks succeed or failures are non-blocking
- 1 if blocking hook fails

### execute-async

Execute hooks asynchronously in background.

```bash
./hook-executor.sh execute-async <hook_type> [args...]
```

**Arguments**:
- `hook_type`: Hook type from registry
- `args`: Additional arguments passed to hook scripts

**Returns**:
- 0 immediately (hooks run in background)

### list

List all registered hooks.

```bash
./hook-executor.sh list
```

**Returns**: 0 (always succeeds)

### list-types

List all hook types from registry.

```bash
./hook-executor.sh list-types
```

**Returns**: 0 (always succeeds)

### validate

Validate hooks.json configuration.

```bash
./hook-executor.sh validate
```

**Returns**:
- 0 if configuration is valid
- 1 if configuration has errors

### logs

Show recent hook execution logs.

```bash
./hook-executor.sh logs [lines]
```

**Arguments**:
- `lines`: Number of log lines to show (default: 50)

**Returns**: 0 (always succeeds)

## Version History

### 1.0.0 (2026-01-11)

Initial release with:
- Hook type registry and configuration system
- Sequential and parallel execution modes
- Timeout handling with graceful fallback
- Comprehensive failure handling (block/warn/continue)
- Async execution support
- Structured logging to .ralph-cache/hooks.log
- CLI interface for hook management
- Configuration validation
- Full integration with BMAD Ralph Plugin lifecycle

## Related Documentation

- [Plugin Architecture](../../README.md)
- [Hook Scripts](./): Individual hook implementations
- [Configuration Reference](./hooks.json): Complete hooks.json schema
