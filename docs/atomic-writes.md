# Atomic File Operations in Ralph

## Overview

Ralph uses atomic file write patterns throughout the codebase to ensure data integrity and prevent corruption from crashes, interruptions, or concurrent access. This document describes the atomic write pattern, when to use it, and how it's implemented in Ralph.

## The Atomic Write Pattern

The atomic write pattern follows this sequence:

1. **Create temp file** - Write content to a temporary file in the same directory as the destination
2. **Validate** - Optionally validate the content (e.g., JSON/YAML validation)
3. **Atomic rename** - Use `mv` to rename the temp file to the final destination

This pattern ensures:
- **No partial writes** - If the write fails, the original file remains unchanged
- **Crash safety** - Process termination during write doesn't corrupt the file
- **Atomic visibility** - Readers see either the old or new content, never partial content

## Implementation

### Utility Functions

Ralph provides three utility functions in `lib/core/utils.sh`:

#### `atomic_write`
General-purpose atomic write for any file type.

```bash
# Write from variable
atomic_write "config.json" "$(jq '.foo = "bar"' config.json)"

# Write from stdin
jq '.foo = "bar"' config.json | atomic_write "config.json"
```

#### `atomic_write_json`
Atomic write with JSON validation before committing.

```bash
# Write JSON with validation
echo '{"foo":"bar"}' | atomic_write_json "config.json"

# From variable
atomic_write_json "config.json" '{"foo":"bar"}'
```

#### `atomic_write_yaml`
Atomic write with YAML validation before committing.

```bash
# Write YAML with validation
echo 'foo: bar' | atomic_write_yaml "config.yaml"

# From variable
atomic_write_yaml "config.yaml" 'foo: bar'
```

### Manual Pattern

For cases where the utility functions aren't suitable, use this pattern:

```bash
# Create temp file in same directory as destination
temp_file=$(mktemp "$(dirname "$dest_file")/.tmp.XXXXXX")

# Write content
echo "content" > "$temp_file"
# OR
jq '.foo = "bar"' input.json > "$temp_file"

# Validate if needed
if ! jq . "$temp_file" >/dev/null 2>&1; then
  rm -f "$temp_file"
  error "Invalid JSON"
  return 1
fi

# Atomic rename
mv "$temp_file" "$dest_file"
```

**Important:** Always create the temp file in the same directory as the destination file. This ensures the `mv` operation is atomic (same filesystem). Cross-filesystem moves may not be atomic.

## When to Use Atomic Writes

### ✅ Always Use Atomic Writes For:

- **Configuration files** - `config.json`, `config.yaml`, `prd.json`
- **State files** - Files tracking execution state (`storyAttempts`, `stats`)
- **Sprint status** - `sprint-status.yaml`
- **Any file where partial writes would corrupt application state**

### ⚠️ Append Operations Are Acceptable For:

- **Log files** - `progress.txt`, `.gate-output.log`
- **Append-only data** where order doesn't critically matter
- **Files where partial writes don't break functionality**

Append operations (`>>`) are generally safe for log files because:
- Partial lines are acceptable in logs
- Logs are human-readable and can tolerate minor inconsistencies
- Losing a single log line during a crash is not a critical failure
- The performance benefit of direct append outweighs atomicity concerns

However, even for logs, if you need guaranteed consistency, consider using atomic writes and file concatenation instead.

## Examples in Ralph Codebase

### Configuration Updates

```bash
# packages/cli/lib/commands/config.sh
temp_file=$(mktemp)
jq '.config.qualityGates.lint = "npm run lint"' ralph/config.json > "$temp_file"
if jq . "$temp_file" >/dev/null 2>&1; then
  mv "$temp_file" ralph/config.json
else
  rm -f "$temp_file"
  error "Failed to update configuration"
fi
```

### Sprint Status Updates

```bash
# ralph/loop.sh - mark_story_complete()
tmp_file=$(mktemp)
yq eval "
  (.epics[].stories[] | select(.id == \"$story_id\")).status = \"completed\" |
  (.epics[] | select(.id == \"$epic_id\")).completed_points += $story_points
" "$SPRINT_STATUS" > "$tmp_file" && mv "$tmp_file" "$SPRINT_STATUS"
```

### Loop Configuration Updates

```bash
# ralph/loop.sh - increment_story_attempts()
tmp_file=$(mktemp)
jq --arg id "$story_id" '
  .storyAttempts[$id] = ((.storyAttempts[$id] // 0) + 1)
' "$CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"
```

### Generator File Creation

```bash
# packages/cli/lib/generator/prd_generator.sh
temp_file=$(mktemp)
echo "$prd_content" > "$temp_file"

# Validate JSON
if ! jq . "$temp_file" >/dev/null 2>&1; then
  rm -f "$temp_file"
  error "Invalid JSON generated"
  return 1
fi

# Atomic move to final location
mv "$temp_file" "$output_file"
```

## Error Handling

Always clean up temp files on error:

```bash
temp_file=$(mktemp)

# Trap to ensure cleanup even on script exit
trap 'rm -f "$temp_file"' EXIT

# Write and validate
echo "$content" > "$temp_file"
if ! validate "$temp_file"; then
  error "Validation failed"
  exit 1  # trap will clean up temp_file
fi

# Atomic move
mv "$temp_file" "$dest_file"
```

## Testing Atomic Writes

To verify atomic writes survive interruptions:

1. **During write** - Send SIGINT/SIGTERM during file write operations
2. **Verify integrity** - Ensure destination file is either old or new content, never partial
3. **No temp files** - Verify no `.tmp.*` files are left behind

Example test:

```bash
# Start a write operation
./write-config.sh &
PID=$!

# Interrupt during write
sleep 0.1
kill -INT $PID

# Verify config.json is valid
jq . config.json >/dev/null && echo "✅ File integrity preserved"

# Verify no temp files left
[[ $(find . -name ".tmp.*" | wc -l) -eq 0 ]] && echo "✅ No temp files leaked"
```

## Performance Considerations

Atomic writes have minimal performance overhead:

- **Temp file creation** - Fast, uses kernel temp file allocation
- **Write** - Same as direct write
- **Rename** - O(1) operation on same filesystem

For high-frequency updates, consider:
- Batching multiple updates into a single atomic write
- Using append for non-critical data
- Background workers for async updates

## Summary

**Key Principles:**
1. Always use atomic writes for critical state files
2. Create temp files in the same directory as the destination
3. Validate before committing (for JSON/YAML)
4. Clean up temp files on error
5. Append is acceptable for logs, but use atomic writes for everything else

**Implementation Checklist:**
- ✅ Create temp file with `mktemp`
- ✅ Write content to temp file
- ✅ Validate content (if applicable)
- ✅ Clean up on validation failure
- ✅ Atomic rename with `mv`
- ✅ No direct writes to critical files

Following these patterns ensures Ralph's state files remain consistent even in the face of crashes, interruptions, and concurrent access.
