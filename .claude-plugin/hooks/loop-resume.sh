#!/usr/bin/env bash
#
# BMAD Ralph Plugin - Loop Resume Hook
# Executed when loop execution is resumed
#
# Usage: ./loop-resume.sh [LOOP_NAME]
#
# Environment:
#   RALPH_LOOP_NAME - Name of the loop (required if not passed as arg)
#   RALPH_NOTIFICATION_WEBHOOK - Optional webhook URL for notifications
#   RALPH_CUSTOM_LOOP_RESUME - Optional custom script to execute after built-in actions

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
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [loop-resume] [$level] $*" | tee -a "$LOG_FILE" >&2
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
  log "ERROR" "Cannot resume archived loop '$LOOP_NAME'"
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

log "INFO" "Loop resume hook triggered for $LOOP_NAME"

# Read loop metadata from config.json
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$CONFIG_FILE")
ITERATIONS_RUN=$(jq -r '.stats.iterationsRun // 0' "$CONFIG_FILE")
STORIES_COMPLETED=$(jq -r '.stats.storiesCompleted // 0' "$CONFIG_FILE")
RESUME_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Calculate pause duration if pause time is available
PAUSE_TIME=$(jq -r '.stats.pausedAt // "null"' "$CONFIG_FILE")
if [[ "$PAUSE_TIME" != "null" ]]; then
  PAUSE_SECONDS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$PAUSE_TIME" "+%s" 2>/dev/null || echo "0")
  RESUME_SECONDS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$RESUME_TIME" "+%s" 2>/dev/null || date +"%s")
  PAUSE_DURATION=$((RESUME_SECONDS - PAUSE_SECONDS))
  PAUSE_HOURS=$((PAUSE_DURATION / 3600))
  PAUSE_MINS=$(((PAUSE_DURATION % 3600) / 60))
  PAUSE_DURATION_STR="${PAUSE_HOURS}h ${PAUSE_MINS}m"
else
  PAUSE_DURATION_STR="unknown"
fi

log "INFO" "Loop: $LOOP_NAME | Branch: $BRANCH_NAME"
log "INFO" "Progress: $STORIES_COMPLETED stories in $ITERATIONS_RUN iterations"
log "INFO" "Paused for: $PAUSE_DURATION_STR"

# Update config.json with resume time and clear pause time
TMP_FILE=$(mktemp)
jq --arg time "$RESUME_TIME" '.stats.resumedAt = $time | del(.stats.pausedAt)' "$CONFIG_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$CONFIG_FILE"
log "INFO" "Updated config.json with resume time: $RESUME_TIME"

# Log lifecycle event to progress.txt
if [[ -f "$PROGRESS_FILE" ]]; then
  {
    echo ""
    echo "## Loop Resume Event"
    echo "Timestamp: $RESUME_TIME"
    echo "Loop: $LOOP_NAME"
    echo "Branch: $BRANCH_NAME"
    echo "Stories completed: $STORIES_COMPLETED"
    echo "Iterations run: $ITERATIONS_RUN"
    echo "Paused for: $PAUSE_DURATION_STR"
    echo "---"
  } >> "$PROGRESS_FILE"
  log "INFO" "Logged loop resume event to progress.txt"
fi

# Send notification (optional)
if [[ -n "${RALPH_NOTIFICATION_WEBHOOK:-}" ]]; then
  NOTIFICATION_PAYLOAD=$(jq -n \
    --arg loop "$LOOP_NAME" \
    --arg branch "$BRANCH_NAME" \
    --argjson iterations "$ITERATIONS_RUN" \
    --argjson completed "$STORIES_COMPLETED" \
    --arg pause_duration "$PAUSE_DURATION_STR" \
    --arg time "$RESUME_TIME" \
    '{
      event: "loop_resume",
      loop: $loop,
      branch: $branch,
      stats: {
        iterations: $iterations,
        completed: $completed,
        pause_duration: $pause_duration
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
if [[ -n "${RALPH_CUSTOM_LOOP_RESUME:-}" ]]; then
  if [[ -f "$RALPH_CUSTOM_LOOP_RESUME" ]] && [[ -x "$RALPH_CUSTOM_LOOP_RESUME" ]]; then
    log "INFO" "Executing custom loop resume script: $RALPH_CUSTOM_LOOP_RESUME"

    # Pass loop context to custom script via environment
    export RALPH_LOOP_NAME="$LOOP_NAME"
    export RALPH_LOOP_DIR="$LOOP_DIR"
    export RALPH_BRANCH_NAME="$BRANCH_NAME"
    export RALPH_ITERATIONS_RUN="$ITERATIONS_RUN"
    export RALPH_STORIES_COMPLETED="$STORIES_COMPLETED"
    export RALPH_PAUSE_DURATION="$PAUSE_DURATION_STR"

    if "$RALPH_CUSTOM_LOOP_RESUME"; then
      log "INFO" "Custom script executed successfully"
    else
      log "WARN" "Custom script failed (exit code: $?)"
    fi
  else
    log "WARN" "Custom script not found or not executable: $RALPH_CUSTOM_LOOP_RESUME"
  fi
fi

# Output summary
echo -e "${GREEN}▶ Loop resume hook completed successfully${NC}"
echo -e "  Loop: ${BLUE}$LOOP_NAME${NC}"
echo -e "  Branch: ${YELLOW}$BRANCH_NAME${NC}"
echo -e "  Progress: ${GREEN}$STORIES_COMPLETED stories${NC} in ${BLUE}$ITERATIONS_RUN iterations${NC}"
echo -e "  Paused for: ${BLUE}$PAUSE_DURATION_STR${NC}"

exit 0
