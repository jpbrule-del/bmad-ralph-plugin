#!/usr/bin/env bash
#
# BMAD Ralph Plugin - Loop Start Hook
# Executed when loop execution begins
#
# Usage: ./loop-start.sh [LOOP_NAME]
#
# Environment:
#   RALPH_LOOP_NAME - Name of the loop (required if not passed as arg)
#   RALPH_NOTIFICATION_WEBHOOK - Optional webhook URL for notifications
#   RALPH_CUSTOM_LOOP_START - Optional custom script to execute after built-in actions

set -euo pipefail

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging
readonly LOG_FILE="${RALPH_CACHE_DIR:-.ralph-cache}/hooks.log"

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [loop-start] [$level] $*" | tee -a "$LOG_FILE" >&2
}

# Parse arguments
LOOP_NAME="${1:-${RALPH_LOOP_NAME:-}}"

# Validate inputs
if [[ -z "$LOOP_NAME" ]]; then
  log "ERROR" "Loop name not provided (pass as arg or set RALPH_LOOP_NAME)"
  exit 1
fi

# Locate loop directory
if [[ -d "ralph/loops/$LOOP_NAME" ]]; then
  LOOP_DIR="ralph/loops/$LOOP_NAME"
elif [[ -d "ralph/archive/"*"-$LOOP_NAME" ]]; then
  log "ERROR" "Cannot start archived loop '$LOOP_NAME'"
  exit 1
else
  log "ERROR" "Loop '$LOOP_NAME' not found"
  exit 1
fi

CONFIG_FILE="$LOOP_DIR/config.json"
PROGRESS_FILE="$LOOP_DIR/progress.txt"

if [[ ! -f "$CONFIG_FILE" ]]; then
  log "ERROR" "Config file not found: $CONFIG_FILE"
  exit 1
fi

log "INFO" "Loop start hook triggered for $LOOP_NAME"

# Read loop metadata from config.json
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$CONFIG_FILE")
MAX_ITERATIONS=$(jq -r '.config.maxIterations // 100' "$CONFIG_FILE")
STUCK_THRESHOLD=$(jq -r '.config.stuckThreshold // 3' "$CONFIG_FILE")
ITERATIONS_RUN=$(jq -r '.stats.iterationsRun // 0' "$CONFIG_FILE")
STORIES_COMPLETED=$(jq -r '.stats.storiesCompleted // 0' "$CONFIG_FILE")
START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update config.json with start time if not already set
if [[ "$(jq -r '.stats.startedAt // "null"' "$CONFIG_FILE")" == "null" ]]; then
  TMP_FILE=$(mktemp)
  jq --arg time "$START_TIME" '.stats.startedAt = $time' "$CONFIG_FILE" > "$TMP_FILE"
  mv "$TMP_FILE" "$CONFIG_FILE"
  log "INFO" "Updated config.json with start time: $START_TIME"
fi

log "INFO" "Loop: $LOOP_NAME | Branch: $BRANCH_NAME"
log "INFO" "Max iterations: $MAX_ITERATIONS | Stuck threshold: $STUCK_THRESHOLD"
log "INFO" "Current progress: $STORIES_COMPLETED stories in $ITERATIONS_RUN iterations"

# Log lifecycle event to progress.txt
if [[ -f "$PROGRESS_FILE" ]]; then
  {
    echo ""
    echo "## Loop Start Event"
    echo "Timestamp: $START_TIME"
    echo "Loop: $LOOP_NAME"
    echo "Branch: $BRANCH_NAME"
    echo "Max iterations: $MAX_ITERATIONS"
    echo "Stuck threshold: $STUCK_THRESHOLD"
    echo "---"
  } >> "$PROGRESS_FILE"
  log "INFO" "Logged loop start event to progress.txt"
fi

# Send notification (optional)
if [[ -n "${RALPH_NOTIFICATION_WEBHOOK:-}" ]]; then
  NOTIFICATION_PAYLOAD=$(jq -n \
    --arg loop "$LOOP_NAME" \
    --arg branch "$BRANCH_NAME" \
    --argjson max_iterations "$MAX_ITERATIONS" \
    --argjson stuck_threshold "$STUCK_THRESHOLD" \
    --argjson iterations "$ITERATIONS_RUN" \
    --argjson completed "$STORIES_COMPLETED" \
    --arg time "$START_TIME" \
    '{
      event: "loop_start",
      loop: $loop,
      branch: $branch,
      config: {
        max_iterations: $max_iterations,
        stuck_threshold: $stuck_threshold
      },
      stats: {
        iterations: $iterations,
        completed: $completed
      },
      timestamp: $time
    }')

  if curl -X POST "$RALPH_NOTIFICATION_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "$NOTIFICATION_PAYLOAD" \
    --silent --show-error --max-time 5 > /dev/null 2>&1; then
    log "INFO" "Notification sent successfully"
  else
    log "WARN" "Failed to send notification"
  fi
fi

# Execute custom script if provided
if [[ -n "${RALPH_CUSTOM_LOOP_START:-}" ]]; then
  if [[ -f "$RALPH_CUSTOM_LOOP_START" ]] && [[ -x "$RALPH_CUSTOM_LOOP_START" ]]; then
    log "INFO" "Executing custom loop start script: $RALPH_CUSTOM_LOOP_START"

    # Pass loop context to custom script via environment
    export RALPH_LOOP_NAME="$LOOP_NAME"
    export RALPH_LOOP_DIR="$LOOP_DIR"
    export RALPH_BRANCH_NAME="$BRANCH_NAME"
    export RALPH_MAX_ITERATIONS="$MAX_ITERATIONS"

    if "$RALPH_CUSTOM_LOOP_START"; then
      log "INFO" "Custom script executed successfully"
    else
      log "WARN" "Custom script failed (exit code: $?)"
    fi
  else
    log "WARN" "Custom script not found or not executable: $RALPH_CUSTOM_LOOP_START"
  fi
fi

# Output summary
echo -e "${GREEN}✓ Loop start hook completed successfully${NC}"
echo -e "  Loop: ${BLUE}$LOOP_NAME${NC}"
echo -e "  Branch: ${YELLOW}$BRANCH_NAME${NC}"
echo -e "  Max iterations: ${BLUE}$MAX_ITERATIONS${NC} | Stuck threshold: ${BLUE}$STUCK_THRESHOLD${NC}"
echo -e "  Current progress: ${GREEN}$STORIES_COMPLETED stories${NC} in ${BLUE}$ITERATIONS_RUN iterations${NC}"

exit 0
