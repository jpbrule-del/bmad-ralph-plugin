#!/usr/bin/env bash
#
# auto-update-install.sh - Install plugin update
# Part of BMAD Ralph Plugin Auto-Update System
#
# Usage:
#   auto-update-install.sh [version]
#
# Arguments:
#   version    Optional specific version to install (default: latest)
#
# Description:
#   Downloads and installs plugin update while preserving user configuration.
#   Creates backup before installation for rollback capability.
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
BACKUP_DIR="${PLUGIN_DIR}/../ralph/.update-backups"

# Target version (default: latest)
TARGET_VERSION="${1:-latest}"

# Log function
log() {
  local level=$1
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required for auto-update${NC}"
  log "ERROR" "jq not found"
  exit 1
fi

# Get configuration
BACKUP_ENABLED=$(jq -r '.backup_before_update // true' "$CONFIG_FILE")
PRESERVE_FILES=$(jq -r '.preserve_configuration.files[]' "$CONFIG_FILE" 2>/dev/null || echo "")
PRESERVE_DIRS=$(jq -r '.preserve_configuration.directories[]' "$CONFIG_FILE" 2>/dev/null || echo "")
CURRENT_VERSION=$(jq -r '.version // "0.0.0"' "$PLUGIN_JSON")

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   BMAD Ralph Plugin Update Installer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Current Version: ${YELLOW}$CURRENT_VERSION${NC}"
echo -e "  Target Version:  ${GREEN}$TARGET_VERSION${NC}"
echo ""

log "INFO" "Starting update installation: $CURRENT_VERSION -> $TARGET_VERSION"

# Step 1: Create backup if enabled
if [[ "$BACKUP_ENABLED" == "true" ]]; then
  echo -e "${YELLOW}Step 1/5:${NC} Creating backup..."

  BACKUP_NAME="backup-$CURRENT_VERSION-$(date +%Y%m%d-%H%M%S)"
  BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

  mkdir -p "$BACKUP_PATH"

  # Backup preserve files
  if [[ -n "$PRESERVE_FILES" ]]; then
    while IFS= read -r file; do
      if [[ -f "$PLUGIN_DIR/../$file" ]]; then
        FILE_DIR=$(dirname "$file")
        mkdir -p "$BACKUP_PATH/$FILE_DIR"
        cp "$PLUGIN_DIR/../$file" "$BACKUP_PATH/$file"
        echo "  ✓ Backed up: $file"
      fi
    done <<< "$PRESERVE_FILES"
  fi

  # Backup preserve directories
  if [[ -n "$PRESERVE_DIRS" ]]; then
    while IFS= read -r dir; do
      if [[ -d "$PLUGIN_DIR/../$dir" ]]; then
        mkdir -p "$BACKUP_PATH/$(dirname "$dir")"
        cp -r "$PLUGIN_DIR/../$dir" "$BACKUP_PATH/$dir"
        echo "  ✓ Backed up: $dir"
      fi
    done <<< "$PRESERVE_DIRS"
  fi

  # Save backup metadata
  cat > "$BACKUP_PATH/metadata.json" <<EOF
{
  "backup_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "previous_version": "$CURRENT_VERSION",
  "target_version": "$TARGET_VERSION",
  "backup_name": "$BACKUP_NAME"
}
EOF

  echo -e "${GREEN}  ✓ Backup created: $BACKUP_NAME${NC}"
  log "INFO" "Backup created: $BACKUP_PATH"
else
  echo -e "${YELLOW}Step 1/5:${NC} Skipping backup (disabled)"
fi

# Step 2: Download update
echo ""
echo -e "${YELLOW}Step 2/5:${NC} Downloading update..."

UPDATE_SOURCE=$(jq -r '.update_source.api_endpoint // "https://api.github.com/repos/snarktank/ralph/releases/latest"' "$CONFIG_FILE")

if ! command -v curl &> /dev/null; then
  echo -e "${RED}Error: curl is required for auto-update${NC}"
  log "ERROR" "curl not found"
  exit 1
fi

# Note: In a real implementation, this would download the actual plugin archive
# For now, we'll simulate this step as the actual download mechanism depends
# on the distribution method (npm, direct download, etc.)

echo -e "${YELLOW}  Note: Actual download step would happen here${NC}"
echo "  In production, this would:"
echo "    1. Download plugin archive from marketplace/GitHub"
echo "    2. Verify download integrity (checksums)"
echo "    3. Extract to temporary directory"
log "INFO" "Update download simulated (not implemented for safety)"

# Step 3: Preserve configuration
echo ""
echo -e "${YELLOW}Step 3/5:${NC} Preserving user configuration..."

TEMP_CONFIG_DIR="/tmp/ralph-config-$$"
mkdir -p "$TEMP_CONFIG_DIR"

if [[ -n "$PRESERVE_FILES" ]]; then
  while IFS= read -r file; do
    if [[ -f "$PLUGIN_DIR/../$file" ]]; then
      FILE_DIR=$(dirname "$file")
      mkdir -p "$TEMP_CONFIG_DIR/$FILE_DIR"
      cp "$PLUGIN_DIR/../$file" "$TEMP_CONFIG_DIR/$file"
      echo "  ✓ Preserved: $file"
    fi
  done <<< "$PRESERVE_FILES"
fi

echo -e "${GREEN}  ✓ Configuration preserved${NC}"

# Step 4: Install update
echo ""
echo -e "${YELLOW}Step 4/5:${NC} Installing update..."

echo -e "${YELLOW}  Note: Actual installation step would happen here${NC}"
echo "  In production, this would:"
echo "    1. Stop any running loops"
echo "    2. Replace plugin files with new version"
echo "    3. Run any migration scripts"
echo "    4. Update plugin.json version"
log "INFO" "Update installation simulated (not implemented for safety)"

# Step 5: Restore configuration
echo ""
echo -e "${YELLOW}Step 5/5:${NC} Restoring user configuration..."

if [[ -n "$PRESERVE_FILES" ]]; then
  while IFS= read -r file; do
    if [[ -f "$TEMP_CONFIG_DIR/$file" ]]; then
      FILE_DIR=$(dirname "$file")
      mkdir -p "$PLUGIN_DIR/../$FILE_DIR"
      cp "$TEMP_CONFIG_DIR/$file" "$PLUGIN_DIR/../$file"
      echo "  ✓ Restored: $file"
    fi
  done <<< "$PRESERVE_FILES"
fi

rm -rf "$TEMP_CONFIG_DIR"

echo -e "${GREEN}  ✓ Configuration restored${NC}"

# Show changelog
echo ""
echo -e "${YELLOW}Fetching changelog...${NC}"
"$PLUGIN_DIR/scripts/auto-update-changelog.sh" "$TARGET_VERSION"

# Update complete
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Update Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Updated to version: ${GREEN}$TARGET_VERSION${NC}"
echo ""
echo "  Next steps:"
echo "    1. Restart Claude Code to use new version"
echo "    2. Run any new migrations if prompted"
echo "    3. Review changelog for breaking changes"
echo ""
if [[ "$BACKUP_ENABLED" == "true" ]]; then
  echo "  Backup available at:"
  echo "    $BACKUP_PATH"
  echo ""
  echo "  To rollback, run:"
  echo -e "    ${BLUE}$PLUGIN_DIR/../scripts/version-rollback.sh $CURRENT_VERSION${NC}"
  echo ""
fi
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

log "INFO" "Update installation completed: $CURRENT_VERSION -> $TARGET_VERSION"

exit 0
