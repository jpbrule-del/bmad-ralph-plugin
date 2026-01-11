#!/usr/bin/env bash
#
# BMAD Ralph Plugin - Stuck Detection Hook
# Detects when loops or stories are stuck and provides diagnostics
#
# Usage: ./stuck-detection.sh [LOOP_NAME] [STORY_ID]
#
# Environment:
#   RALPH_LOOP_NAME - Name of the loop (required if not passed as arg)
#   RALPH_STORY_ID - Story ID to check (optional, checks current story if not provided)
#   RALPH_STUCK_THRESHOLD - Number of attempts before considering stuck (default: 3)
#   RALPH_NOTIFICATION_WEBHOOK - Optional webhook URL for stuck notifications
#   RALPH_CACHE_DIR - Cache directory for logs (default: .ralph-cache)

set -euo pipefail

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging
readonly LOG_FILE="${RALPH_CACHE_DIR:-.ralph-cache}/hooks.log"

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [stuck-detection] [$level] $*" | tee -a "$LOG_FILE" >&2
}

# Parse arguments
LOOP_NAME="${1:-${RALPH_LOOP_NAME:-}}"
STORY_ID="${2:-${RALPH_STORY_ID:-}}"
STUCK_THRESHOLD="${RALPH_STUCK_THRESHOLD:-3}"

# Validate inputs
if [[ -z "$LOOP_NAME" ]]; then
  log "ERROR" "Loop name not provided (pass as arg or set RALPH_LOOP_NAME)"
  exit 1
fi

# Locate loop directory
if [[ -d "ralph/loops/$LOOP_NAME" ]]; then
  LOOP_DIR="ralph/loops/$LOOP_NAME"
elif [[ -d "ralph/archive/"*"-$LOOP_NAME" ]]; then
  log "WARN" "Loop '$LOOP_NAME' is archived, skipping stuck detection"
  exit 0
else
  log "ERROR" "Loop '$LOOP_NAME' not found"
  exit 1
fi

CONFIG_FILE="$LOOP_DIR/config.json"
PROGRESS_FILE="$LOOP_DIR/progress.txt"
SPRINT_STATUS="${RALPH_SPRINT_STATUS:-docs/sprint-status.yaml}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  log "ERROR" "Config file not found: $CONFIG_FILE"
  exit 1
fi

log "INFO" "Running stuck detection for loop '$LOOP_NAME'"

# Load configuration
if ! LOOP_CONFIG=$(jq '.' "$CONFIG_FILE" 2>/dev/null); then
  log "ERROR" "Failed to parse config.json"
  exit 1
fi

# Override stuck threshold from loop config if available
CONFIG_THRESHOLD=$(echo "$LOOP_CONFIG" | jq -r '.config.stuckThreshold // empty')
if [[ -n "$CONFIG_THRESHOLD" && "$CONFIG_THRESHOLD" != "null" ]]; then
  STUCK_THRESHOLD="$CONFIG_THRESHOLD"
fi

log "INFO" "Using stuck threshold: $STUCK_THRESHOLD attempts"

# Read loop statistics
ITERATIONS_RUN=$(echo "$LOOP_CONFIG" | jq -r '.stats.iterationsRun // 0')
STORIES_COMPLETED=$(echo "$LOOP_CONFIG" | jq -r '.stats.storiesCompleted // 0')
MAX_ITERATIONS=$(echo "$LOOP_CONFIG" | jq -r '.config.maxIterations // 100')

# Detection flags
STORY_STUCK=false
LOOP_STUCK=false
STUCK_STORIES=()
DIAGNOSTICS=()
RESOLUTION_ACTIONS=()

# ============================================================================
# STORY-LEVEL STUCK DETECTION
# ============================================================================

log "INFO" "Checking for stuck stories..."

# Get all story notes
STORY_NOTES=$(echo "$LOOP_CONFIG" | jq -r '.storyNotes // {}')

# Check if specific story provided
if [[ -n "$STORY_ID" ]]; then
  log "INFO" "Checking specific story: $STORY_ID"

  STORY_DATA=$(echo "$STORY_NOTES" | jq --arg story "$STORY_ID" '.[$story] // empty')

  if [[ -n "$STORY_DATA" && "$STORY_DATA" != "null" ]]; then
    ATTEMPTS=$(echo "$STORY_DATA" | jq -r '.attempts // 0')
    TITLE=$(echo "$STORY_DATA" | jq -r '.title // "Unknown"')

    if [[ "$ATTEMPTS" -ge "$STUCK_THRESHOLD" ]]; then
      STORY_STUCK=true
      STUCK_STORIES+=("$STORY_ID")
      log "WARN" "Story $STORY_ID is stuck (attempts: $ATTEMPTS >= threshold: $STUCK_THRESHOLD)"
      DIAGNOSTICS+=("Story-level: $STORY_ID '$TITLE' has been attempted $ATTEMPTS times")
    fi
  fi
else
  # Check all stories for stuck conditions
  while IFS= read -r story_id; do
    [[ -z "$story_id" || "$story_id" == "null" ]] && continue

    STORY_DATA=$(echo "$STORY_NOTES" | jq --arg story "$story_id" '.[$story] // empty')
    ATTEMPTS=$(echo "$STORY_DATA" | jq -r '.attempts // 0')
    TITLE=$(echo "$STORY_DATA" | jq -r '.title // "Unknown"')
    COMPLETED_AT=$(echo "$STORY_DATA" | jq -r '.completedAt // empty')

    # Only check incomplete stories
    if [[ -z "$COMPLETED_AT" || "$COMPLETED_AT" == "null" ]]; then
      if [[ "$ATTEMPTS" -ge "$STUCK_THRESHOLD" ]]; then
        STORY_STUCK=true
        STUCK_STORIES+=("$story_id")
        log "WARN" "Story $story_id is stuck (attempts: $ATTEMPTS >= threshold: $STUCK_THRESHOLD)"
        DIAGNOSTICS+=("Story-level: $story_id '$TITLE' has been attempted $ATTEMPTS times")
      fi
    fi
  done < <(echo "$STORY_NOTES" | jq -r 'keys[]')
fi

# ============================================================================
# LOOP-LEVEL STUCK DETECTION
# ============================================================================

log "INFO" "Checking for loop-level stuckness..."

# Check if loop is approaching iteration limit without progress
REMAINING_ITERATIONS=$((MAX_ITERATIONS - ITERATIONS_RUN))
AVG_ITERATIONS_PER_STORY=$(echo "$LOOP_CONFIG" | jq -r '.stats.averageIterationsPerStory // 0')

# Count total and remaining stories
if [[ -f "$SPRINT_STATUS" ]] && command -v yq > /dev/null 2>&1; then
  TOTAL_STORIES=$(yq eval '[.epics[].stories[]] | length' "$SPRINT_STATUS" 2>/dev/null || echo "0")
  NOT_STARTED_STORIES=$(yq eval '[.epics[].stories[] | select(.status == "not_started")] | length' "$SPRINT_STATUS" 2>/dev/null || echo "0")
  IN_PROGRESS_STORIES=$(yq eval '[.epics[].stories[] | select(.status == "in_progress")] | length' "$SPRINT_STATUS" 2>/dev/null || echo "0")
  REMAINING_STORIES=$((NOT_STARTED_STORIES + IN_PROGRESS_STORIES))
else
  TOTAL_STORIES=0
  REMAINING_STORIES=0
fi

# Detect loop stuckness scenarios
if [[ "$REMAINING_ITERATIONS" -lt 10 && "$REMAINING_STORIES" -gt 5 ]]; then
  LOOP_STUCK=true
  DIAGNOSTICS+=("Loop-level: Only $REMAINING_ITERATIONS iterations remaining but $REMAINING_STORIES stories left")
  log "WARN" "Loop approaching iteration limit with many stories remaining"
fi

# Check if loop is spinning without completing stories
if [[ "$ITERATIONS_RUN" -gt 20 && "$STORIES_COMPLETED" -eq 0 ]]; then
  LOOP_STUCK=true
  DIAGNOSTICS+=("Loop-level: $ITERATIONS_RUN iterations completed but no stories finished")
  log "WARN" "Loop has run $ITERATIONS_RUN iterations without completing any stories"
fi

# Check if average iterations per story is very high
if [[ $(echo "$AVG_ITERATIONS_PER_STORY > 5" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
  LOOP_STUCK=true
  DIAGNOSTICS+=("Loop-level: Average iterations per story is very high ($AVG_ITERATIONS_PER_STORY)")
  log "WARN" "Loop has high average iterations per story: $AVG_ITERATIONS_PER_STORY"
fi

# ============================================================================
# GENERATE RESOLUTION ACTIONS
# ============================================================================

if [[ "$STORY_STUCK" == true ]]; then
  RESOLUTION_ACTIONS+=("• Review stuck story details and error logs in progress.txt")
  RESOLUTION_ACTIONS+=("• Run quality gates manually to identify specific failures")
  RESOLUTION_ACTIONS+=("• Consider adjusting story acceptance criteria or implementation approach")
  RESOLUTION_ACTIONS+=("• Manual intervention may be required to unblock the story")

  if [[ ${#STUCK_STORIES[@]} -gt 0 ]]; then
    RESOLUTION_ACTIONS+=("• Stuck stories: ${STUCK_STORIES[*]}")
  fi
fi

if [[ "$LOOP_STUCK" == true ]]; then
  RESOLUTION_ACTIONS+=("• Review loop configuration and increase maxIterations if needed")
  RESOLUTION_ACTIONS+=("• Consider breaking down large stories into smaller tasks")
  RESOLUTION_ACTIONS+=("• Review quality gate configuration - they may be too strict")
  RESOLUTION_ACTIONS+=("• Check if custom instructions need adjustment")
  RESOLUTION_ACTIONS+=("• Consider pausing loop and reviewing overall approach")
fi

# ============================================================================
# SEND NOTIFICATION (if stuck condition detected)
# ============================================================================

if [[ "$STORY_STUCK" == true || "$LOOP_STUCK" == true ]]; then
  log "ERROR" "STUCK CONDITION DETECTED for loop '$LOOP_NAME'"

  # Send webhook notification if configured
  if [[ -n "${RALPH_NOTIFICATION_WEBHOOK:-}" ]]; then
    DIAGNOSTICS_JSON=$(printf '%s\n' "${DIAGNOSTICS[@]}" | jq -R . | jq -s .)
    ACTIONS_JSON=$(printf '%s\n' "${RESOLUTION_ACTIONS[@]}" | jq -R . | jq -s .)
    STUCK_STORIES_JSON=$(printf '%s\n' "${STUCK_STORIES[@]}" | jq -R . | jq -s .)

    NOTIFICATION_PAYLOAD=$(jq -n \
      --arg loop "$LOOP_NAME" \
      --argjson story_stuck "$STORY_STUCK" \
      --argjson loop_stuck "$LOOP_STUCK" \
      --argjson diagnostics "$DIAGNOSTICS_JSON" \
      --argjson actions "$ACTIONS_JSON" \
      --argjson stuck_stories "$STUCK_STORIES_JSON" \
      --argjson iterations "$ITERATIONS_RUN" \
      --argjson completed "$STORIES_COMPLETED" \
      --argjson threshold "$STUCK_THRESHOLD" \
      --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{
        event: "stuck_detected",
        loop: $loop,
        stuck: {
          story_level: $story_stuck,
          loop_level: $loop_stuck,
          threshold: $threshold,
          stuck_stories: $stuck_stories
        },
        diagnostics: $diagnostics,
        resolution_actions: $actions,
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
      log "INFO" "Stuck notification sent successfully"
    else
      log "WARN" "Failed to send stuck notification"
    fi
  fi

  # Write diagnostics to progress file
  if [[ -f "$PROGRESS_FILE" ]]; then
    {
      echo ""
      echo "## STUCK CONDITION DETECTED - $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo "Threshold: $STUCK_THRESHOLD attempts"
      echo ""
      echo "### Diagnostics:"
      for diag in "${DIAGNOSTICS[@]}"; do
        echo "- $diag"
      done
      echo ""
      echo "### Suggested Resolution Actions:"
      for action in "${RESOLUTION_ACTIONS[@]}"; do
        echo "$action"
      done
      echo ""
    } >> "$PROGRESS_FILE"
    log "INFO" "Diagnostics written to progress.txt"
  fi

  # Output user-friendly summary
  echo ""
  echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║                  🚨 STUCK CONDITION DETECTED 🚨                ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Loop:${NC} ${BLUE}$LOOP_NAME${NC}"
  echo -e "${YELLOW}Threshold:${NC} $STUCK_THRESHOLD attempts"
  echo -e "${YELLOW}Story-level stuck:${NC} $STORY_STUCK"
  echo -e "${YELLOW}Loop-level stuck:${NC} $LOOP_STUCK"
  echo ""

  if [[ ${#DIAGNOSTICS[@]} -gt 0 ]]; then
    echo -e "${MAGENTA}Diagnostics:${NC}"
    for diag in "${DIAGNOSTICS[@]}"; do
      echo -e "  ${RED}✗${NC} $diag"
    done
    echo ""
  fi

  if [[ ${#RESOLUTION_ACTIONS[@]} -gt 0 ]]; then
    echo -e "${CYAN}Suggested Actions:${NC}"
    for action in "${RESOLUTION_ACTIONS[@]}"; do
      echo -e "  $action"
    done
    echo ""
  fi

  echo -e "${YELLOW}Review progress.txt and logs for detailed information.${NC}"
  echo ""

  # Exit with warning status (non-blocking per hooks.json on_failure: warn)
  exit 0
else
  log "INFO" "No stuck conditions detected"
  echo -e "${GREEN}✓ No stuck conditions detected${NC}"
  echo -e "  Loop: ${BLUE}$LOOP_NAME${NC}"
  echo -e "  Iterations: ${YELLOW}$ITERATIONS_RUN${NC} | Stories completed: ${GREEN}$STORIES_COMPLETED${NC}"
  echo -e "  Threshold: ${YELLOW}$STUCK_THRESHOLD${NC} attempts"
  exit 0
fi
