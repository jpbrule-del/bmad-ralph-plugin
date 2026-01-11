#!/usr/bin/env bash
#
# auto-update-defer.sh - Defer plugin update
# Part of BMAD Ralph Plugin Auto-Update System
#
# Usage:
#   auto-update-defer.sh <version> [days]
#
# Arguments:
#   version    Version to defer (e.g., "1.1.0")
#   days       Number of days to defer (default: 7)
#
# Description:
#   Defers a specific version update for a specified period.
#   Auto-update checks will skip this version until defer period expires.
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

# Parse arguments
if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error: Version argument required${NC}"
  echo "Usage: $0 <version> [days]"
  exit 1
fi

VERSION="$1"
DAYS="${2:-7}"

# Log function
log() {
  local level=$1
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required${NC}"
  log "ERROR" "jq not found"
  exit 1
fi

# Calculate defer_until timestamp
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  DEFER_UNTIL=$(date -u -v+"${DAYS}"d +"%Y-%m-%dT%H:%M:%SZ")
else
  # Linux
  DEFER_UNTIL=$(date -u -d "+${DAYS} days" +"%Y-%m-%dT%H:%M:%SZ")
fi

# Update configuration
jq --arg version "$VERSION" \
   --arg defer_until "$DEFER_UNTIL" \
   '.deferred_updates[$version] = $defer_until' \
   "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Update Deferred${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Version:       ${YELLOW}$VERSION${NC}"
echo -e "  Deferred for:  ${YELLOW}$DAYS days${NC}"
echo -e "  Defer until:   ${YELLOW}$DEFER_UNTIL${NC}"
echo ""
echo "  Auto-update checks will skip this version until the defer"
echo "  period expires."
echo ""
echo "  To cancel deferral:"
echo -e "    ${BLUE}jq 'del(.deferred_updates[\"$VERSION\"])' $CONFIG_FILE${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

log "INFO" "Deferred version $VERSION until $DEFER_UNTIL"

exit 0
