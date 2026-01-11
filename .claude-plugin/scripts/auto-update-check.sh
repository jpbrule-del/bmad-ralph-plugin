#!/usr/bin/env bash
#
# auto-update-check.sh - Check for plugin updates
# Part of BMAD Ralph Plugin Auto-Update System
#
# Usage:
#   auto-update-check.sh [--force]
#
# Flags:
#   --force    Ignore check interval and force update check
#
# Description:
#   Checks for available plugin updates according to configured interval.
#   Notifies user if update is available and not deferred.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.claude-plugin}"
CONFIG_FILE="$PLUGIN_DIR/auto-update.json"
PLUGIN_JSON="$PLUGIN_DIR/plugin.json"
LOG_FILE="${PLUGIN_DIR}/../ralph/logs/auto-update.log"

# Parse arguments
FORCE_CHECK=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE_CHECK=true
fi

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")"

# Log function
log() {
  local level=$1
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}Warning: jq not found, skipping auto-update check${NC}"
  log "WARN" "jq not found, skipping auto-update check"
  exit 0
fi

# Check if auto-update is enabled
if [[ ! -f "$CONFIG_FILE" ]]; then
  log "INFO" "Auto-update config not found, skipping check"
  exit 0
fi

ENABLED=$(jq -r '.enabled // true' "$CONFIG_FILE")
if [[ "$ENABLED" != "true" ]]; then
  log "INFO" "Auto-update disabled, skipping check"
  exit 0
fi

# Get configuration
CHECK_INTERVAL=$(jq -r '.check_interval_hours // 24' "$CONFIG_FILE")
LAST_CHECK=$(jq -r '.last_check_timestamp // "null"' "$CONFIG_FILE")
AUTO_INSTALL=$(jq -r '.auto_install // false' "$CONFIG_FILE")
UPDATE_SOURCE=$(jq -r '.update_source.api_endpoint // "https://api.github.com/repos/snarktank/ralph/releases/latest"' "$CONFIG_FILE")
CURRENT_VERSION=$(jq -r '.version // "0.0.0"' "$PLUGIN_JSON")

# Check if enough time has passed
if [[ "$FORCE_CHECK" != "true" ]] && [[ "$LAST_CHECK" != "null" ]]; then
  CURRENT_TIME=$(date +%s)
  LAST_CHECK_TIME=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$LAST_CHECK" +%s 2>/dev/null || echo 0)
  TIME_DIFF=$(( (CURRENT_TIME - LAST_CHECK_TIME) / 3600 ))

  if [[ $TIME_DIFF -lt $CHECK_INTERVAL ]]; then
    log "INFO" "Check interval not elapsed (${TIME_DIFF}h / ${CHECK_INTERVAL}h)"
    exit 0
  fi
fi

# Update last check timestamp
jq --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '.last_check_timestamp = $timestamp' \
  "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

log "INFO" "Checking for updates (current: $CURRENT_VERSION)"

# Fetch latest release info
if ! command -v curl &> /dev/null; then
  echo -e "${YELLOW}Warning: curl not found, cannot check for updates${NC}"
  log "WARN" "curl not found, cannot check for updates"
  exit 0
fi

RELEASE_DATA=$(curl -s "$UPDATE_SOURCE" || echo "{}")

if [[ "$RELEASE_DATA" == "{}" ]]; then
  log "ERROR" "Failed to fetch release data from $UPDATE_SOURCE"
  exit 0
fi

LATEST_VERSION=$(echo "$RELEASE_DATA" | jq -r '.tag_name // .name // "0.0.0"' | sed 's/^v//')

# Compare versions
if [[ "$LATEST_VERSION" == "$CURRENT_VERSION" ]]; then
  log "INFO" "Already on latest version: $CURRENT_VERSION"
  exit 0
fi

# Check if this version is deferred
DEFERRED_UNTIL=$(jq -r --arg version "$LATEST_VERSION" '.deferred_updates[$version] // "null"' "$CONFIG_FILE")
if [[ "$DEFERRED_UNTIL" != "null" ]]; then
  CURRENT_TIME=$(date +%s)
  DEFER_TIME=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$DEFERRED_UNTIL" +%s 2>/dev/null || echo 0)

  if [[ $CURRENT_TIME -lt $DEFER_TIME ]]; then
    log "INFO" "Update to $LATEST_VERSION deferred until $DEFERRED_UNTIL"
    exit 0
  fi
fi

# Update available!
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   BMAD Ralph Plugin Update Available${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Current Version: ${YELLOW}$CURRENT_VERSION${NC}"
echo -e "  Latest Version:  ${GREEN}$LATEST_VERSION${NC}"
echo ""

# Show changelog if enabled
SHOW_CHANGELOG=$(jq -r '.changelog_display.show_on_notify // true' "$CONFIG_FILE")
if [[ "$SHOW_CHANGELOG" == "true" ]]; then
  CHANGELOG_URL=$(echo "$RELEASE_DATA" | jq -r '.html_url // ""')
  if [[ -n "$CHANGELOG_URL" ]]; then
    echo -e "  Release Notes: ${BLUE}$CHANGELOG_URL${NC}"
    echo ""
  fi

  # Show release body if available
  RELEASE_BODY=$(echo "$RELEASE_DATA" | jq -r '.body // ""')
  if [[ -n "$RELEASE_BODY" ]]; then
    echo "  Release Notes:"
    echo "$RELEASE_BODY" | head -n 20 | sed 's/^/  /'
    echo ""
  fi
fi

echo "  To update:"
echo -e "    ${BLUE}claude-plugin install --update bmad-ralph${NC}"
echo ""
echo "  Or run:"
echo -e "    ${BLUE}$PLUGIN_DIR/scripts/auto-update-install.sh${NC}"
echo ""
echo "  To defer this update:"
echo -e "    ${BLUE}$PLUGIN_DIR/scripts/auto-update-defer.sh $LATEST_VERSION${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

log "INFO" "Update available: $CURRENT_VERSION -> $LATEST_VERSION"

# Auto-install if configured
if [[ "$AUTO_INSTALL" == "true" ]]; then
  echo -e "${YELLOW}Auto-install enabled, installing update...${NC}"
  log "INFO" "Auto-installing update $LATEST_VERSION"
  "$PLUGIN_DIR/scripts/auto-update-install.sh" "$LATEST_VERSION"
fi

exit 0
