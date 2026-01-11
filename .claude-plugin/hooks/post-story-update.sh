#!/usr/bin/env bash
#
# BMAD Ralph Plugin - Post-Story Update Hook
# Executed after story completion to update progress and trigger follow-up actions
#
# Usage: ./post-story-update.sh [LOOP_NAME] [STORY_ID]
#
# Environment:
#   RALPH_LOOP_NAME - Name of the loop (required if not passed as arg)
#   RALPH_STORY_ID - Story ID that was completed (required if not passed as arg)
#   RALPH_NOTIFICATION_WEBHOOK - Optional webhook URL for notifications
#   RALPH_AUTO_PICKUP_NEXT - If "true", automatically picks up next story (default: false)

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
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [post-story] [$level] $*" | tee -a "$LOG_FILE" >&2
}

# Parse arguments
LOOP_NAME="${1:-${RALPH_LOOP_NAME:-}}"
STORY_ID="${2:-${RALPH_STORY_ID:-}}"

# Validate inputs
if [[ -z "$LOOP_NAME" ]]; then
  log "ERROR" "Loop name not provided (pass as arg or set RALPH_LOOP_NAME)"
  exit 1
fi

if [[ -z "$STORY_ID" ]]; then
  log "ERROR" "Story ID not provided (pass as arg or set RALPH_STORY_ID)"
  exit 1
fi

# Locate loop directory
if [[ -d "ralph/loops/$LOOP_NAME" ]]; then
  LOOP_DIR="ralph/loops/$LOOP_NAME"
elif [[ -d "ralph/archive/"*"-$LOOP_NAME" ]]; then
  log "WARN" "Loop '$LOOP_NAME' is archived, skipping post-story actions"
  exit 0
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

if [[ ! -f "$PROGRESS_FILE" ]]; then
  log "ERROR" "Progress file not found: $PROGRESS_FILE"
  exit 1
fi

log "INFO" "Post-story hook triggered for $LOOP_NAME - $STORY_ID"

# Read story metadata from config.json
if ! STORY_DATA=$(jq -r --arg story "$STORY_ID" '.storyNotes[$story] // empty' "$CONFIG_FILE"); then
  log "ERROR" "Failed to read story data from config.json"
  exit 1
fi

if [[ -z "$STORY_DATA" || "$STORY_DATA" == "null" ]]; then
  log "WARN" "Story '$STORY_ID' not found in storyNotes"
  STORY_TITLE="Unknown Story"
  STORY_POINTS=0
  STORY_EPIC="EPIC-000"
  STORY_ATTEMPTS=0
else
  STORY_TITLE=$(echo "$STORY_DATA" | jq -r '.title // "Unknown Story"')
  STORY_POINTS=$(echo "$STORY_DATA" | jq -r '.points // 0')
  STORY_EPIC=$(echo "$STORY_DATA" | jq -r '.epic // "EPIC-000"')
  STORY_ATTEMPTS=$(echo "$STORY_DATA" | jq -r '.attempts // 0')
fi

# Read overall stats
ITERATIONS_RUN=$(jq -r '.stats.iterationsRun // 0' "$CONFIG_FILE")
STORIES_COMPLETED=$(jq -r '.stats.storiesCompleted // 0' "$CONFIG_FILE")
COMPLETION_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Calculate completion metrics
AVG_ITERATIONS=$(echo "scale=2; $ITERATIONS_RUN / $STORIES_COMPLETED" | bc 2>/dev/null || echo "0")

log "INFO" "Story completed: $STORY_ID - $STORY_TITLE ($STORY_POINTS points)"
log "INFO" "Iterations: $ITERATIONS_RUN | Stories completed: $STORIES_COMPLETED | Avg: $AVG_ITERATIONS"

# Update progress.txt with completion summary
{
  echo ""
  echo "## Story Completion - $STORY_ID"
  echo "Completed at: $COMPLETION_TIME"
  echo "Title: $STORY_TITLE"
  echo "Epic: $STORY_EPIC"
  echo "Points: $STORY_POINTS"
  echo "Attempts: $STORY_ATTEMPTS"
  echo "Total iterations: $ITERATIONS_RUN"
  echo "Total stories completed: $STORIES_COMPLETED"
  echo "Average iterations per story: $AVG_ITERATIONS"
} >> "$PROGRESS_FILE"

log "INFO" "Updated progress.txt with completion summary"

# Send notification (optional)
if [[ -n "${RALPH_NOTIFICATION_WEBHOOK:-}" ]]; then
  NOTIFICATION_PAYLOAD=$(jq -n \
    --arg loop "$LOOP_NAME" \
    --arg story "$STORY_ID" \
    --arg title "$STORY_TITLE" \
    --arg epic "$STORY_EPIC" \
    --argjson points "$STORY_POINTS" \
    --argjson attempts "$STORY_ATTEMPTS" \
    --argjson iterations "$ITERATIONS_RUN" \
    --argjson completed "$STORIES_COMPLETED" \
    --arg time "$COMPLETION_TIME" \
    '{
      event: "story_completed",
      loop: $loop,
      story: {
        id: $story,
        title: $title,
        epic: $epic,
        points: $points,
        attempts: $attempts
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

# Trigger next story pickup (optional)
AUTO_PICKUP="${RALPH_AUTO_PICKUP_NEXT:-false}"
if [[ "$AUTO_PICKUP" == "true" ]]; then
  log "INFO" "Auto-pickup enabled, triggering next story"

  # Find next story with status "not_started"
  SPRINT_STATUS="${RALPH_SPRINT_STATUS:-docs/sprint-status.yaml}"

  if [[ ! -f "$SPRINT_STATUS" ]]; then
    log "WARN" "Sprint status file not found: $SPRINT_STATUS"
  else
    # Use yq to find next not_started story
    if command -v yq > /dev/null 2>&1; then
      NEXT_STORY=$(yq eval '.epics[].stories[] | select(.status == "not_started") | .id' "$SPRINT_STATUS" | head -n 1)

      if [[ -n "$NEXT_STORY" ]]; then
        log "INFO" "Next story: $NEXT_STORY"
        echo "NEXT_STORY=$NEXT_STORY" >> "${RALPH_CACHE_DIR:-.ralph-cache}/next-story.env"
      else
        log "INFO" "No more stories to pick up (all completed or in progress)"
      fi
    else
      log "WARN" "yq not available, cannot determine next story"
    fi
  fi
fi

# Log completion metrics for analytics
log "INFO" "Story completion metrics logged"

# Output summary
echo -e "${GREEN}✓ Post-story hook completed successfully${NC}"
echo -e "  Story: ${BLUE}$STORY_ID${NC} - $STORY_TITLE"
echo -e "  Points: ${YELLOW}$STORY_POINTS${NC} | Attempts: ${YELLOW}$STORY_ATTEMPTS${NC}"
echo -e "  Total progress: ${GREEN}$STORIES_COMPLETED stories${NC} in ${BLUE}$ITERATIONS_RUN iterations${NC}"

exit 0
