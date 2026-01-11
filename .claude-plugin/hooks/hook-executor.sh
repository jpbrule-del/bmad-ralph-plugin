#!/usr/bin/env bash
# Hook Execution Engine for BMAD Ralph Plugin
# Orchestrates hook execution based on hooks.json configuration

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_CONFIG="$HOOKS_DIR/hooks.json"
CACHE_DIR="${RALPH_CACHE_DIR:-.ralph-cache}"
LOG_FILE="$CACHE_DIR/hooks.log"
PLUGIN_ROOT="$(dirname "$HOOKS_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# LOGGING
# ============================================================================

log_hook_execution() {
  local hook_type="$1"
  local hook_name="$2"
  local status="$3"
  local duration="$4"
  local message="${5:-}"

  mkdir -p "$CACHE_DIR"

  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  cat >> "$LOG_FILE" <<EOF
[$timestamp] HOOK_EXECUTION
  Type: $hook_type
  Name: $hook_name
  Status: $status
  Duration: ${duration}ms
  Message: $message

EOF
}

log_error() {
  echo -e "${RED}ERROR:${NC} $*" >&2
  mkdir -p "$CACHE_DIR"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ERROR: $*" >> "$LOG_FILE"
}

log_info() {
  echo -e "${BLUE}INFO:${NC} $*"
  mkdir -p "$CACHE_DIR"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] INFO: $*" >> "$LOG_FILE"
}

log_warn() {
  echo -e "${YELLOW}WARN:${NC} $*"
  mkdir -p "$CACHE_DIR"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WARN: $*" >> "$LOG_FILE"
}

log_success() {
  echo -e "${GREEN}SUCCESS:${NC} $*"
}

# ============================================================================
# HOOK CONFIGURATION PARSING
# ============================================================================

# Check if jq is available
if ! command -v jq &> /dev/null; then
  log_error "jq is required but not installed. Please install jq to use the hook system."
  exit 1
fi

# Validate hooks.json exists
if [[ ! -f "$HOOKS_CONFIG" ]]; then
  log_error "hooks.json not found at: $HOOKS_CONFIG"
  exit 1
fi

# Parse hooks by type
get_hooks_for_type() {
  local hook_type="$1"

  jq -r --arg type "$hook_type" '
    .hooks[] |
    select(.type == $type) |
    select(.enabled // true) |
    @json
  ' "$HOOKS_CONFIG"
}

# Get hook type configuration
get_hook_type_config() {
  local hook_type="$1"

  jq -r --arg type "$hook_type" '
    .hook_types[$type] // {}
  ' "$HOOKS_CONFIG"
}

# Get execution config
get_execution_config() {
  jq -r '.execution_config' "$HOOKS_CONFIG"
}

# ============================================================================
# TIMEOUT HANDLING
# ============================================================================

# Execute command with timeout
execute_with_timeout() {
  local timeout_ms="$1"
  shift
  local cmd=("$@")

  local timeout_sec=$((timeout_ms / 1000))

  # Use timeout command if available, otherwise just execute
  if command -v timeout &> /dev/null; then
    timeout "${timeout_sec}s" "${cmd[@]}"
    return $?
  elif command -v gtimeout &> /dev/null; then
    # macOS with coreutils installed
    gtimeout "${timeout_sec}s" "${cmd[@]}"
    return $?
  else
    # No timeout available, just execute
    "${cmd[@]}"
    return $?
  fi
}

# ============================================================================
# HOOK EXECUTION
# ============================================================================

execute_single_hook() {
  local hook_json="$1"
  local context_args=("${@:2}")

  local hook_name hook_script hook_timeout hook_required on_failure
  hook_name=$(echo "$hook_json" | jq -r '.name')
  hook_script=$(echo "$hook_json" | jq -r '.script')
  hook_timeout=$(echo "$hook_json" | jq -r '.timeout // 5000')
  hook_required=$(echo "$hook_json" | jq -r '.required // false')
  on_failure=$(echo "$hook_json" | jq -r '.on_failure // "warn"')

  # Parse additional args from hook config
  local hook_args=()
  mapfile -t hook_args < <(echo "$hook_json" | jq -r '.args[]? // empty')

  local script_path="$HOOKS_DIR/$hook_script"

  # Validate script exists and is executable
  if [[ ! -f "$script_path" ]]; then
    log_error "Hook script not found: $script_path"
    if [[ "$hook_required" == "true" ]]; then
      return 1
    fi
    return 0
  fi

  if [[ ! -x "$script_path" ]]; then
    log_warn "Hook script not executable, attempting to make executable: $script_path"
    chmod +x "$script_path" || true
  fi

  # Execute hook with timeout
  local start_time end_time duration exit_code
  start_time=$(date +%s%3N)

  log_info "Executing hook: $hook_name"

  set +e
  execute_with_timeout "$hook_timeout" "$script_path" "${hook_args[@]}" "${context_args[@]}"
  exit_code=$?
  set -e

  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))

  # Handle execution result
  if [[ $exit_code -eq 0 ]]; then
    log_success "Hook completed: $hook_name (${duration}ms)"
    log_hook_execution "$(echo "$hook_json" | jq -r '.type')" "$hook_name" "success" "$duration" "Completed successfully"
    return 0
  elif [[ $exit_code -eq 124 ]] || [[ $exit_code -eq 143 ]]; then
    # Timeout
    log_error "Hook timed out: $hook_name (timeout: ${hook_timeout}ms)"
    log_hook_execution "$(echo "$hook_json" | jq -r '.type')" "$hook_name" "timeout" "$duration" "Execution timed out"

    case "$on_failure" in
      block)
        log_error "Hook failure blocks execution (on_failure=block)"
        return 1
        ;;
      warn)
        log_warn "Hook failure logged as warning (on_failure=warn)"
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  else
    # Other failure
    log_error "Hook failed: $hook_name (exit code: $exit_code, duration: ${duration}ms)"
    log_hook_execution "$(echo "$hook_json" | jq -r '.type')" "$hook_name" "failure" "$duration" "Exit code: $exit_code"

    case "$on_failure" in
      block)
        log_error "Hook failure blocks execution (on_failure=block)"
        return 1
        ;;
      warn)
        log_warn "Hook failure logged as warning (on_failure=warn)"
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  fi
}

# Execute hooks sequentially
execute_hooks_sequential() {
  local hook_type="$1"
  shift
  local context_args=("$@")

  local hooks_json
  hooks_json=$(get_hooks_for_type "$hook_type")

  if [[ -z "$hooks_json" ]]; then
    log_info "No enabled hooks found for type: $hook_type"
    return 0
  fi

  # Sort hooks by execution_order and execute
  local hook
  while IFS= read -r hook; do
    if [[ -n "$hook" ]]; then
      execute_single_hook "$hook" "${context_args[@]}" || return $?
    fi
  done < <(echo "$hooks_json" | jq -s 'sort_by(.execution_order // 999)[] | @json')

  return 0
}

# Execute hooks in parallel
execute_hooks_parallel() {
  local hook_type="$1"
  shift
  local context_args=("$@")

  local hooks_json
  hooks_json=$(get_hooks_for_type "$hook_type")

  if [[ -z "$hooks_json" ]]; then
    log_info "No enabled hooks found for type: $hook_type"
    return 0
  fi

  local max_concurrent
  max_concurrent=$(get_execution_config | jq -r '.max_concurrent_hooks // 3')

  local pids=()
  local hook

  # Execute hooks in parallel with concurrency limit
  while IFS= read -r hook; do
    if [[ -n "$hook" ]]; then
      # Wait if we've reached max concurrent hooks
      while [[ ${#pids[@]} -ge $max_concurrent ]]; do
        for i in "${!pids[@]}"; do
          if ! kill -0 "${pids[$i]}" 2>/dev/null; then
            unset 'pids[i]'
          fi
        done
        pids=("${pids[@]}") # Rebuild array
        sleep 0.1
      done

      # Execute hook in background
      execute_single_hook "$hook" "${context_args[@]}" &
      pids+=($!)
    fi
  done < <(echo "$hooks_json" | jq -s 'sort_by(.execution_order // 999)[] | @json')

  # Wait for all background hooks to complete
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
    fi
  done

  return $failed
}

# Main hook execution dispatcher
execute_hooks() {
  local hook_type="$1"
  shift
  local context_args=("$@")

  # Validate hook type exists
  local hook_type_config
  hook_type_config=$(get_hook_type_config "$hook_type")

  if [[ "$hook_type_config" == "null" ]] || [[ "$hook_type_config" == "{}" ]]; then
    log_error "Unknown hook type: $hook_type"
    return 1
  fi

  # Get execution order for this hook type
  local execution_order
  execution_order=$(echo "$hook_type_config" | jq -r '.execution_order // "sequential"')

  log_info "Executing hooks for type: $hook_type (mode: $execution_order)"

  # Execute based on execution order
  if [[ "$execution_order" == "parallel" ]]; then
    execute_hooks_parallel "$hook_type" "${context_args[@]}"
  else
    execute_hooks_sequential "$hook_type" "${context_args[@]}"
  fi
}

# ============================================================================
# ASYNC HOOK EXECUTION
# ============================================================================

execute_hooks_async() {
  local hook_type="$1"
  shift
  local context_args=("$@")

  log_info "Starting async hook execution for type: $hook_type"

  # Execute hooks in background
  (
    execute_hooks "$hook_type" "${context_args[@]}"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      log_info "Async hooks completed successfully for type: $hook_type"
    else
      log_error "Async hooks failed for type: $hook_type (exit code: $exit_code)"
    fi
  ) &

  log_info "Async hooks dispatched for type: $hook_type (PID: $!)"
}

# ============================================================================
# CLI INTERFACE
# ============================================================================

show_usage() {
  cat <<EOF
Hook Execution Engine for BMAD Ralph Plugin

Usage:
  $0 <command> <hook_type> [args...]

Commands:
  execute       Execute hooks for specified type (synchronous)
  execute-async Execute hooks for specified type (asynchronous)
  list          List all registered hooks
  list-types    List all hook types
  validate      Validate hooks.json configuration
  logs          Show recent hook execution logs

Hook Types:
  plugin-load, pre-commit, post-commit, post-command, post-story,
  loop-start, loop-pause, loop-resume, loop-complete,
  iteration-milestone, quality-gate-failure, stuck-detection

Examples:
  $0 execute plugin-load
  $0 execute pre-commit
  $0 execute-async post-story STORY-001 completed
  $0 list
  $0 validate

Environment Variables:
  RALPH_CACHE_DIR       Cache directory for logs (default: .ralph-cache)

EOF
}

list_hooks() {
  echo -e "${CYAN}Registered Hooks:${NC}\n"

  jq -r '.hooks[] |
    select(.enabled // true) |
    "\(.type):\(.name) (order: \(.execution_order // 999), timeout: \(.timeout // 5000)ms, on_failure: \(.on_failure // "warn"))"
  ' "$HOOKS_CONFIG" | sort
}

list_hook_types() {
  echo -e "${CYAN}Hook Types:${NC}\n"

  jq -r '.hook_types | to_entries[] |
    "\(.key) - \(.value.description) (phase: \(.value.execution_phase), execution: \(.value.execution_order))"
  ' "$HOOKS_CONFIG"
}

validate_config() {
  log_info "Validating hooks.json configuration..."

  # Validate JSON syntax
  if ! jq empty "$HOOKS_CONFIG" 2>/dev/null; then
    log_error "Invalid JSON syntax in hooks.json"
    return 1
  fi

  # Validate required fields
  local required_fields=("version" "hook_types" "execution_config" "hooks")
  for field in "${required_fields[@]}"; do
    if ! jq -e ".$field" "$HOOKS_CONFIG" > /dev/null 2>&1; then
      log_error "Missing required field: $field"
      return 1
    fi
  done

  # Validate each hook
  local invalid_hooks=0
  while IFS= read -r hook_name; do
    local hook_type
    hook_type=$(jq -r --arg name "$hook_name" '.hooks[] | select(.name == $name) | .type' "$HOOKS_CONFIG")

    if ! jq -e --arg type "$hook_type" '.hook_types[$type]' "$HOOKS_CONFIG" > /dev/null 2>&1; then
      log_error "Hook '$hook_name' has invalid type: $hook_type"
      ((invalid_hooks++))
    fi
  done < <(jq -r '.hooks[].name' "$HOOKS_CONFIG")

  if [[ $invalid_hooks -gt 0 ]]; then
    log_error "Found $invalid_hooks invalid hook(s)"
    return 1
  fi

  log_success "hooks.json configuration is valid"
  return 0
}

show_logs() {
  local lines="${1:-50}"

  if [[ ! -f "$LOG_FILE" ]]; then
    log_info "No hook execution logs found"
    return 0
  fi

  echo -e "${CYAN}Recent Hook Execution Logs (last $lines lines):${NC}\n"
  tail -n "$lines" "$LOG_FILE"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
    execute)
      if [[ $# -eq 0 ]]; then
        log_error "Hook type required"
        show_usage
        exit 1
      fi
      execute_hooks "$@"
      ;;
    execute-async)
      if [[ $# -eq 0 ]]; then
        log_error "Hook type required"
        show_usage
        exit 1
      fi
      execute_hooks_async "$@"
      ;;
    list)
      list_hooks
      ;;
    list-types)
      list_hook_types
      ;;
    validate)
      validate_config
      ;;
    logs)
      show_logs "${1:-50}"
      ;;
    *)
      log_error "Unknown command: $command"
      show_usage
      exit 1
      ;;
  esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
