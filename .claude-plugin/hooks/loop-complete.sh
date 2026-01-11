#!/usr/bin/env bash
#
# BMAD Ralph Plugin - Loop Complete Hook
# Executed when loop execution completes
#
# Usage: ./loop-complete.sh [LOOP_NAME]
#
# Environment:
#   RALPH_LOOP_NAME - Name of the loop (required if not passed as arg)
#   RALPH_NOTIFICATION_WEBHOOK - Optional webhook URL for notifications
#   RALPH_CUSTOM_LOOP_COMPLETE - Optional custom script to execute after built-in actions

set -euo pipefail

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging
readonly LOG_FILE="${RALPH_CACHE_DIR:-.ralph-cache}/hooks.log"

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [loop-complete] [$level] $*" | tee -a "$LOG_FILE" >&2
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
  log "ERROR" "Loop '$LOOP_NAME' is already archived"
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

log "INFO" "Loop complete hook triggered for $LOOP_NAME"

# Read loop metadata from config.json
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$CONFIG_FILE")
ITERATIONS_RUN=$(jq -r '.stats.iterationsRun // 0' "$CONFIG_FILE")
STORIES_COMPLETED=$(jq -r '.stats.storiesCompleted // 0' "$CONFIG_FILE")
MAX_ITERATIONS=$(jq -r '.config.maxIterations // 100' "$CONFIG_FILE")
COMPLETE_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Calculate total duration if start time is available
START_TIME=$(jq -r '.stats.startedAt // "null"' "$CONFIG_FILE")
if [[ "$START_TIME" != "null" ]]; then
  START_SECONDS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" "+%s" 2>/dev/null || echo "0")
  COMPLETE_SECONDS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$COMPLETE_TIME" "+%s" 2>/dev/null || date +"%s")
  TOTAL_DURATION=$((COMPLETE_SECONDS - START_SECONDS))
  DURATION_HOURS=$((TOTAL_DURATION / 3600))
  DURATION_MINS=$(((TOTAL_DURATION % 3600) / 60))
  TOTAL_DURATION_STR="${DURATION_HOURS}h ${DURATION_MINS}m"
else
  TOTAL_DURATION_STR="unknown"
fi

# Calculate average iterations per story
if [[ $STORIES_COMPLETED -gt 0 ]]; then
  AVG_ITERATIONS=$(echo "scale=2; $ITERATIONS_RUN / $STORIES_COMPLETED" | bc 2>/dev/null || echo "0.00")
else
  AVG_ITERATIONS="0.00"
fi

# Calculate completion rate
COMPLETION_RATE=$(echo "scale=1; ($STORIES_COMPLETED / $MAX_ITERATIONS) * 100" | bc 2>/dev/null || echo "0.0")

log "INFO" "Loop: $LOOP_NAME | Branch: $BRANCH_NAME"
log "INFO" "Stories completed: $STORIES_COMPLETED | Iterations: $ITERATIONS_RUN"
log "INFO" "Average iterations per story: $AVG_ITERATIONS"
log "INFO" "Total duration: $TOTAL_DURATION_STR"

# Update config.json with completion time
TMP_FILE=$(mktemp)
jq --arg time "$COMPLETE_TIME" --arg avg "$AVG_ITERATIONS" \
  '.stats.completedAt = $time | .stats.averageIterationsPerStory = ($avg | tonumber)' \
  "$CONFIG_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$CONFIG_FILE"
log "INFO" "Updated config.json with completion time: $COMPLETE_TIME"

# Log lifecycle event to progress.txt
if [[ -f "$PROGRESS_FILE" ]]; then
  {
    echo ""
    echo "## Loop Complete Event"
    echo "Timestamp: $COMPLETE_TIME"
    echo "Loop: $LOOP_NAME"
    echo "Branch: $BRANCH_NAME"
    echo "Stories completed: $STORIES_COMPLETED"
    echo "Iterations run: $ITERATIONS_RUN"
    echo "Average iterations per story: $AVG_ITERATIONS"
    echo "Total duration: $TOTAL_DURATION_STR"
    echo "Completion rate: ${COMPLETION_RATE}%"
    echo "---"
    echo ""
    echo "# Loop Execution Summary"
    echo ""
    echo "Loop '$LOOP_NAME' completed successfully!"
    echo ""
    echo "## Statistics"
    echo "- Total stories completed: $STORIES_COMPLETED"
    echo "- Total iterations: $ITERATIONS_RUN"
    echo "- Average iterations per story: $AVG_ITERATIONS"
    echo "- Total duration: $TOTAL_DURATION_STR"
    echo ""
    echo "## Next Steps"
    echo "- Run \`/bmad-ralph:archive $LOOP_NAME\` to archive this loop with feedback"
    echo "- Run \`/bmad-ralph:feedback-report\` to view aggregate feedback analytics"
    echo ""
  } >> "$PROGRESS_FILE"
  log "INFO" "Logged loop complete event and summary to progress.txt"
fi

# Send notification (optional)
if [[ -n "${RALPH_NOTIFICATION_WEBHOOK:-}" ]]; then
  NOTIFICATION_PAYLOAD=$(jq -n \
    --arg loop "$LOOP_NAME" \
    --arg branch "$BRANCH_NAME" \
    --argjson iterations "$ITERATIONS_RUN" \
    --argjson completed "$STORIES_COMPLETED" \
    --arg avg_iterations "$AVG_ITERATIONS" \
    --arg duration "$TOTAL_DURATION_STR" \
    --arg completion_rate "${COMPLETION_RATE}%" \
    --arg time "$COMPLETE_TIME" \
    '{
      event: "loop_complete",
      loop: $loop,
      branch: $branch,
      stats: {
        iterations: $iterations,
        completed: $completed,
        avg_iterations: $avg_iterations,
        duration: $duration,
        completion_rate: $completion_rate
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
if [[ -n "${RALPH_CUSTOM_LOOP_COMPLETE:-}" ]]; then
  if [[ -f "$RALPH_CUSTOM_LOOP_COMPLETE" ]] && [[ -x "$RALPH_CUSTOM_LOOP_COMPLETE" ]]; then
    log "INFO" "Executing custom loop complete script: $RALPH_CUSTOM_LOOP_COMPLETE"

    # Pass loop context to custom script via environment
    export RALPH_LOOP_NAME="$LOOP_NAME"
    export RALPH_LOOP_DIR="$LOOP_DIR"
    export RALPH_BRANCH_NAME="$BRANCH_NAME"
    export RALPH_ITERATIONS_RUN="$ITERATIONS_RUN"
    export RALPH_STORIES_COMPLETED="$STORIES_COMPLETED"
    export RALPH_AVG_ITERATIONS="$AVG_ITERATIONS"
    export RALPH_TOTAL_DURATION="$TOTAL_DURATION_STR"
    export RALPH_COMPLETION_RATE="$COMPLETION_RATE"

    if "$RALPH_CUSTOM_LOOP_COMPLETE"; then
      log "INFO" "Custom script executed successfully"
    else
      log "WARN" "Custom script failed (exit code: $?)"
    fi
  else
    log "WARN" "Custom script not found or not executable: $RALPH_CUSTOM_LOOP_COMPLETE"
  fi
fi

# Output summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ LOOP COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Loop: ${CYAN}$LOOP_NAME${NC}"
echo -e "  Branch: ${YELLOW}$BRANCH_NAME${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Stories completed: ${GREEN}$STORIES_COMPLETED${NC}"
echo -e "  ${BLUE}→${NC} Total iterations: ${BLUE}$ITERATIONS_RUN${NC}"
echo -e "  ${YELLOW}⌀${NC} Average per story: ${YELLOW}$AVG_ITERATIONS${NC}"
echo -e "  ${CYAN}⏱${NC}  Total duration: ${CYAN}$TOTAL_DURATION_STR${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  • Run ${YELLOW}/bmad-ralph:archive $LOOP_NAME${NC} to archive with feedback"
echo -e "  • Run ${YELLOW}/bmad-ralph:feedback-report${NC} for analytics"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

exit 0
