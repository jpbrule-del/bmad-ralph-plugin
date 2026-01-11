#!/usr/bin/env bash
# Show plugin permissions during installation
# This displays what the bmad-ralph plugin can access

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_JSON="$PLUGIN_DIR/plugin.json"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if plugin.json exists
if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "Error: plugin.json not found at $PLUGIN_JSON" >&2
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found, cannot display permissions" >&2
  exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  BMAD Ralph Plugin - Permissions${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This plugin requires the following permissions:"
echo ""

# Extract and display filesystem permissions
echo -e "${GREEN}📁 File System Access:${NC}"
READ_PATHS=$(jq -r '.permissions.filesystem.read[]' "$PLUGIN_JSON" 2>/dev/null | sed 's/^/  • Read: /')
WRITE_PATHS=$(jq -r '.permissions.filesystem.write[]' "$PLUGIN_JSON" 2>/dev/null | sed 's/^/  • Write: /')

if [[ -n "$READ_PATHS" ]]; then
  echo "$READ_PATHS"
fi
if [[ -n "$WRITE_PATHS" ]]; then
  echo "$WRITE_PATHS"
fi
echo ""

# Extract and display git permissions
echo -e "${GREEN}🔧 Git Operations:${NC}"
GIT_ALLOWED=$(jq -r '.permissions.process.execute[]' "$PLUGIN_JSON" 2>/dev/null | grep "^git$" || echo "")
if [[ -n "$GIT_ALLOWED" ]]; then
  echo "  • Create branches, commits, and push changes"
  echo "  • Read repository status and history"
fi
echo ""

# Extract and display process execution permissions
echo -e "${GREEN}⚙️  Process Execution:${NC}"
PROCESSES=$(jq -r '.permissions.process.execute[]' "$PLUGIN_JSON" 2>/dev/null | sed 's/^/  • /')
if [[ -n "$PROCESSES" ]]; then
  echo "$PROCESSES"
fi
echo ""

# Extract and display network permissions
echo -e "${GREEN}🌐 Network Access:${NC}"
MCP_SERVERS=$(jq -r '.permissions.network.mcp[]' "$PLUGIN_JSON" 2>/dev/null | sed 's/^/  • MCP Server: /')
if [[ -n "$MCP_SERVERS" ]]; then
  echo "$MCP_SERVERS"
else
  echo "  • None"
fi
echo ""

# Show why these permissions are needed
echo -e "${YELLOW}ℹ️  Why these permissions?${NC}"
echo "  Ralph automates your BMAD sprint by:"
echo "  • Reading sprint stories from docs/sprint-status.yaml"
echo "  • Executing quality gates (lint, test, build)"
echo "  • Creating git commits for completed stories"
echo "  • Writing progress logs to ralph/"
echo "  • Optionally researching via Perplexity MCP server"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

exit 0
