#!/usr/bin/env bash
#
# auto-update-changelog.sh - Display changelog for version
# Part of BMAD Ralph Plugin Auto-Update System
#
# Usage:
#   auto-update-changelog.sh [version]
#
# Arguments:
#   version    Version to show changelog for (default: latest)
#
# Description:
#   Fetches and displays changelog for specified version.
#   Supports multiple formats and sources.
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
LOG_FILE="${PLUGIN_DIR}/../ralph/logs/auto-update.log"

# Target version
VERSION="${1:-latest}"

# Log function
log() {
  local level=$1
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}Warning: jq not found, cannot display changelog${NC}"
  log "WARN" "jq not found"
  exit 0
fi

# Get configuration
UPDATE_SOURCE=$(jq -r '.update_source.api_endpoint // "https://api.github.com/repos/snarktank/ralph/releases/latest"' "$CONFIG_FILE")
MAX_LINES=$(jq -r '.changelog_display.max_lines // 50' "$CONFIG_FILE")

# Fetch release data
if ! command -v curl &> /dev/null; then
  echo -e "${YELLOW}Warning: curl not found, cannot fetch changelog${NC}"
  log "WARN" "curl not found"
  exit 0
fi

if [[ "$VERSION" == "latest" ]]; then
  RELEASE_URL="$UPDATE_SOURCE"
else
  # Construct URL for specific version
  BASE_URL=$(echo "$UPDATE_SOURCE" | sed 's|/latest$||')
  RELEASE_URL="$BASE_URL/tags/v$VERSION"
fi

RELEASE_DATA=$(curl -s "$RELEASE_URL" || echo "{}")

if [[ "$RELEASE_DATA" == "{}" ]]; then
  echo -e "${YELLOW}Warning: Could not fetch changelog${NC}"
  log "WARN" "Failed to fetch changelog from $RELEASE_URL"
  exit 0
fi

# Extract changelog information
VERSION_TAG=$(echo "$RELEASE_DATA" | jq -r '.tag_name // .name // "unknown"')
RELEASE_NAME=$(echo "$RELEASE_DATA" | jq -r '.name // "Release"')
RELEASE_DATE=$(echo "$RELEASE_DATA" | jq -r '.published_at // ""' | cut -d'T' -f1)
RELEASE_BODY=$(echo "$RELEASE_DATA" | jq -r '.body // ""')
RELEASE_URL=$(echo "$RELEASE_DATA" | jq -r '.html_url // ""')

# Display changelog
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Changelog: $RELEASE_NAME${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Version:   ${GREEN}$VERSION_TAG${NC}"
if [[ -n "$RELEASE_DATE" ]]; then
  echo -e "  Date:      ${YELLOW}$RELEASE_DATE${NC}"
fi
if [[ -n "$RELEASE_URL" ]]; then
  echo -e "  URL:       ${BLUE}$RELEASE_URL${NC}"
fi
echo ""

if [[ -n "$RELEASE_BODY" ]]; then
  echo "  Release Notes:"
  echo ""
  echo "$RELEASE_BODY" | head -n "$MAX_LINES" | sed 's/^/  /'

  LINE_COUNT=$(echo "$RELEASE_BODY" | wc -l)
  if [[ $LINE_COUNT -gt $MAX_LINES ]]; then
    echo ""
    echo -e "  ${YELLOW}... (truncated, see full changelog at URL above)${NC}"
  fi
else
  echo "  No release notes available."
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

log "INFO" "Displayed changelog for version $VERSION_TAG"

exit 0
