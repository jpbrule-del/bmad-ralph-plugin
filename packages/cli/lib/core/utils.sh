#!/usr/bin/env bash
# ralph utilities - Shared utility functions

# Source output utilities for logging
readonly UTILS_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
source "$UTILS_LIB_DIR/core/output.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# ATOMIC FILE OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Atomic write pattern: write to temp file, then rename
# This ensures no partial writes occur on failure or interruption
#
# Usage:
#   atomic_write <destination_file> <content>
#   echo "content" | atomic_write <destination_file>
#
# Examples:
#   atomic_write "config.json" "$(jq '.foo = "bar"' config.json)"
#   jq '.foo = "bar"' config.json | atomic_write "config.json"
#
atomic_write() {
  local dest_file="$1"
  local content="${2:-}"

  # Validate destination file is provided
  if [[ -z "$dest_file" ]]; then
    error "atomic_write: destination file path is required"
    return 1
  fi

  # Create temp file in same directory as destination for atomic rename
  local dest_dir
  dest_dir=$(dirname "$dest_file")
  local temp_file
  temp_file=$(mktemp "$dest_dir/.tmp.XXXXXX") || {
    error "atomic_write: failed to create temp file in $dest_dir"
    return 1
  }

  # Write content from argument or stdin
  if [[ -n "$content" ]]; then
    echo "$content" > "$temp_file"
  else
    cat > "$temp_file"
  fi

  local write_status=$?
  if [[ $write_status -ne 0 ]]; then
    rm -f "$temp_file"
    error "atomic_write: failed to write content to temp file"
    return 1
  fi

  # Atomic rename
  if ! mv "$temp_file" "$dest_file"; then
    rm -f "$temp_file"
    error "atomic_write: failed to rename temp file to $dest_file"
    return 1
  fi

  return 0
}

# Atomic write for JSON files with validation
# Validates JSON before committing the write
#
# Usage:
#   atomic_write_json <destination_file> <json_content>
#   echo '{"foo":"bar"}' | atomic_write_json <destination_file>
#
atomic_write_json() {
  local dest_file="$1"
  local content="${2:-}"

  # Validate destination file is provided
  if [[ -z "$dest_file" ]]; then
    error "atomic_write_json: destination file path is required"
    return 1
  fi

  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
    error "atomic_write_json: jq is required but not installed"
    return 1
  fi

  # Create temp file in same directory as destination
  local dest_dir
  dest_dir=$(dirname "$dest_file")
  local temp_file
  temp_file=$(mktemp "$dest_dir/.tmp.XXXXXX") || {
    error "atomic_write_json: failed to create temp file in $dest_dir"
    return 1
  }

  # Write content from argument or stdin
  if [[ -n "$content" ]]; then
    echo "$content" > "$temp_file"
  else
    cat > "$temp_file"
  fi

  local write_status=$?
  if [[ $write_status -ne 0 ]]; then
    rm -f "$temp_file"
    error "atomic_write_json: failed to write content to temp file"
    return 1
  fi

  # Validate JSON
  if ! jq . "$temp_file" >/dev/null 2>&1; then
    rm -f "$temp_file"
    error "atomic_write_json: invalid JSON content"
    return 1
  fi

  # Atomic rename
  if ! mv "$temp_file" "$dest_file"; then
    rm -f "$temp_file"
    error "atomic_write_json: failed to rename temp file to $dest_file"
    return 1
  fi

  return 0
}

# Atomic write for YAML files with validation
# Validates YAML before committing the write
#
# Usage:
#   atomic_write_yaml <destination_file> <yaml_content>
#   echo 'foo: bar' | atomic_write_yaml <destination_file>
#
atomic_write_yaml() {
  local dest_file="$1"
  local content="${2:-}"

  # Validate destination file is provided
  if [[ -z "$dest_file" ]]; then
    error "atomic_write_yaml: destination file path is required"
    return 1
  fi

  # Check if yq is available
  if ! command -v yq >/dev/null 2>&1; then
    error "atomic_write_yaml: yq is required but not installed"
    return 1
  fi

  # Create temp file in same directory as destination
  local dest_dir
  dest_dir=$(dirname "$dest_file")
  local temp_file
  temp_file=$(mktemp "$dest_dir/.tmp.XXXXXX") || {
    error "atomic_write_yaml: failed to create temp file in $dest_dir"
    return 1
  }

  # Write content from argument or stdin
  if [[ -n "$content" ]]; then
    echo "$content" > "$temp_file"
  else
    cat > "$temp_file"
  fi

  local write_status=$?
  if [[ $write_status -ne 0 ]]; then
    rm -f "$temp_file"
    error "atomic_write_yaml: failed to write content to temp file"
    return 1
  fi

  # Validate YAML
  if ! yq . "$temp_file" >/dev/null 2>&1; then
    rm -f "$temp_file"
    error "atomic_write_yaml: invalid YAML content"
    return 1
  fi

  # Atomic rename
  if ! mv "$temp_file" "$dest_file"; then
    rm -f "$temp_file"
    error "atomic_write_yaml: failed to rename temp file to $dest_file"
    return 1
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# NOTES ON FILE OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHEN TO USE ATOMIC WRITES:
# - Configuration files (config.json, config.yaml, prd.json)
# - State files that track loop execution (storyAttempts, stats)
# - Sprint status files (sprint-status.yaml)
# - Any file where partial writes would corrupt application state
#
# WHEN APPEND IS ACCEPTABLE:
# - Log files (progress.txt, .gate-output.log)
# - Files where partial writes don't break functionality
# - Append-only data structures where order doesn't matter critically
#
# Note: Append operations (>>) are generally safe for log files because:
# - Partial lines are acceptable in logs
# - Logs are human-readable and can tolerate minor inconsistencies
# - Losing a single log line during a crash is not a critical failure
# - The performance benefit of direct append outweighs atomicity concerns
#
# However, for critical state files, always use atomic writes to ensure:
# - No partial writes on process termination
# - No corruption from concurrent access
# - Consistent state after crashes or interruptions
#
