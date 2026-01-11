#!/usr/bin/env bash
# install-validate.sh - Validate plugin installation
# Part of BMAD Ralph Plugin
# Version: 1.0.0

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATION_LOG="${PLUGIN_DIR}/../.ralph-cache/validation.log"
VERBOSE="${RALPH_VALIDATION_VERBOSE:-false}"

# Create log directory
mkdir -p "$(dirname "$VALIDATION_LOG")"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] $message" >> "$VALIDATION_LOG"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${message}"
    fi
}

# Validation results
VALIDATION_PASSED=true
VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()

# Print header
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  BMAD Ralph Plugin - Installation Validation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

log "INFO" "Starting installation validation"

# ═══════════════════════════════════════════════════════════════════════════
# 1. VERIFY PLUGIN STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[1/5]${NC} Checking plugin structure..."

REQUIRED_DIRS=(
    "commands"
    "skills"
    "agents"
    "hooks"
)

REQUIRED_FILES=(
    "plugin.json"
    "marketplace.json"
    ".mcp.json"
    "hooks/hooks.json"
)

structure_ok=true
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ ! -d "${PLUGIN_DIR}/${dir}" ]]; then
        VALIDATION_ERRORS+=("Missing directory: ${dir}")
        structure_ok=false
        log "ERROR" "Missing directory: ${dir}"
    fi
done

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "${PLUGIN_DIR}/${file}" ]]; then
        VALIDATION_ERRORS+=("Missing file: ${file}")
        structure_ok=false
        log "ERROR" "Missing file: ${file}"
    fi
done

if [[ "$structure_ok" == "true" ]]; then
    echo -e "   ${GREEN}✓${NC} Plugin structure complete"
    log "INFO" "Plugin structure validation passed"
else
    echo -e "   ${RED}✗${NC} Plugin structure incomplete"
    VALIDATION_PASSED=false
fi

# ═══════════════════════════════════════════════════════════════════════════
# 2. VERIFY COMMANDS
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[2/5]${NC} Verifying commands..."

EXPECTED_COMMANDS=(
    "init"
    "create"
    "run"
    "status"
    "list"
    "show"
    "edit"
    "clone"
    "delete"
    "archive"
    "unarchive"
    "config"
    "feedback-report"
)

commands_ok=true
command_count=0

for cmd in "${EXPECTED_COMMANDS[@]}"; do
    cmd_file="${PLUGIN_DIR}/commands/${cmd}.md"
    if [[ -f "$cmd_file" ]]; then
        ((command_count++))
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "   ${GREEN}✓${NC} /bmad-ralph:${cmd}"
        fi
        log "INFO" "Command registered: /bmad-ralph:${cmd}"
    else
        VALIDATION_ERRORS+=("Missing command: /bmad-ralph:${cmd}")
        commands_ok=false
        echo -e "   ${RED}✗${NC} /bmad-ralph:${cmd}"
        log "ERROR" "Missing command: /bmad-ralph:${cmd}"
    fi
done

if [[ "$commands_ok" == "true" ]]; then
    echo -e "   ${GREEN}✓${NC} All ${command_count} commands registered"
    log "INFO" "All commands validated successfully"
else
    echo -e "   ${RED}✗${NC} Some commands missing"
    VALIDATION_PASSED=false
fi

# ═══════════════════════════════════════════════════════════════════════════
# 3. VERIFY HOOKS
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[3/5]${NC} Verifying hooks..."

hooks_ok=true
hook_count=0
enabled_hook_count=0

if command -v jq &> /dev/null; then
    hooks_json="${PLUGIN_DIR}/hooks/hooks.json"

    if [[ -f "$hooks_json" ]]; then
        # Count total hooks
        hook_count=$(jq '.hooks | length' "$hooks_json" 2>/dev/null || echo "0")

        # Count enabled hooks
        enabled_hook_count=$(jq '[.hooks[] | select(.enabled == true)] | length' "$hooks_json" 2>/dev/null || echo "0")

        # Verify hook scripts exist
        hook_scripts=$(jq -r '.hooks[] | select(.enabled == true) | .script' "$hooks_json" 2>/dev/null || echo "")

        if [[ -n "$hook_scripts" ]]; then
            while IFS= read -r script; do
                script_path="${PLUGIN_DIR}/hooks/${script}"
                if [[ ! -f "$script_path" ]]; then
                    VALIDATION_WARNINGS+=("Hook script not found: ${script}")
                    log "WARN" "Hook script not found: ${script}"
                elif [[ ! -x "$script_path" ]]; then
                    VALIDATION_WARNINGS+=("Hook script not executable: ${script}")
                    log "WARN" "Hook script not executable: ${script}"
                fi
            done <<< "$hook_scripts"
        fi

        echo -e "   ${GREEN}✓${NC} ${enabled_hook_count}/${hook_count} hooks enabled"
        log "INFO" "Hooks validated: ${enabled_hook_count}/${hook_count} enabled"
    else
        VALIDATION_ERRORS+=("hooks.json not found")
        hooks_ok=false
        log "ERROR" "hooks.json not found"
    fi
else
    VALIDATION_WARNINGS+=("jq not available - cannot validate hooks.json")
    log "WARN" "jq not available - cannot validate hooks.json"
    echo -e "   ${YELLOW}⚠${NC} Cannot validate hooks (jq not available)"
fi

if [[ "$hooks_ok" == "false" ]]; then
    echo -e "   ${RED}✗${NC} Hooks validation failed"
    VALIDATION_PASSED=false
fi

# ═══════════════════════════════════════════════════════════════════════════
# 4. VERIFY DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[4/5]${NC} Verifying dependencies..."

deps_ok=true

# Check required dependencies
check_dependency() {
    local dep="$1"
    local min_version="$2"

    if command -v "$dep" &> /dev/null; then
        local version
        case "$dep" in
            jq)
                version=$(jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
                ;;
            yq)
                version=$(yq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
                ;;
            git)
                version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
                ;;
        esac

        echo -e "   ${GREEN}✓${NC} ${dep} ${version:-installed}"
        log "INFO" "Dependency available: ${dep} ${version:-unknown}"
        return 0
    else
        VALIDATION_ERRORS+=("Missing required dependency: ${dep} >= ${min_version}")
        echo -e "   ${RED}✗${NC} ${dep} (required: >= ${min_version})"
        log "ERROR" "Missing dependency: ${dep} >= ${min_version}"
        deps_ok=false
        return 1
    fi
}

check_dependency "jq" "1.6"
check_dependency "yq" "4.0"
check_dependency "git" "2.0"

if [[ "$deps_ok" == "false" ]]; then
    VALIDATION_PASSED=false
fi

# ═══════════════════════════════════════════════════════════════════════════
# 5. VERIFY MCP CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}[5/5]${NC} Verifying MCP configuration..."

mcp_ok=true
mcp_json="${PLUGIN_DIR}/.mcp.json"

if [[ -f "$mcp_json" ]]; then
    if command -v jq &> /dev/null; then
        # Validate JSON syntax
        if jq empty "$mcp_json" 2>/dev/null; then
            # Check for Perplexity server
            server_count=$(jq '.mcpServers | length' "$mcp_json" 2>/dev/null || echo "0")

            if [[ "$server_count" -gt 0 ]]; then
                echo -e "   ${GREEN}✓${NC} MCP configuration valid (${server_count} server(s) configured)"
                log "INFO" "MCP configuration valid: ${server_count} server(s)"

                # Check if PERPLEXITY_API_KEY is set
                if [[ -z "${PERPLEXITY_API_KEY:-}" ]]; then
                    VALIDATION_WARNINGS+=("PERPLEXITY_API_KEY environment variable not set")
                    echo -e "   ${YELLOW}⚠${NC} PERPLEXITY_API_KEY not set (MCP features may not work)"
                    log "WARN" "PERPLEXITY_API_KEY not set"
                fi
            else
                VALIDATION_WARNINGS+=("No MCP servers configured")
                echo -e "   ${YELLOW}⚠${NC} No MCP servers configured"
                log "WARN" "No MCP servers configured"
            fi
        else
            VALIDATION_ERRORS+=("Invalid MCP configuration JSON")
            mcp_ok=false
            echo -e "   ${RED}✗${NC} Invalid MCP configuration"
            log "ERROR" "Invalid MCP configuration JSON"
        fi
    else
        VALIDATION_WARNINGS+=("Cannot validate MCP config (jq not available)")
        echo -e "   ${YELLOW}⚠${NC} Cannot validate MCP config (jq not available)"
        log "WARN" "Cannot validate MCP config - jq not available"
    fi
else
    VALIDATION_ERRORS+=("MCP configuration file not found")
    mcp_ok=false
    echo -e "   ${RED}✗${NC} MCP configuration not found"
    log "ERROR" "MCP configuration file not found"
fi

if [[ "$mcp_ok" == "false" ]]; then
    VALIDATION_PASSED=false
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ "$VALIDATION_PASSED" == "true" ]]; then
    if [[ ${#VALIDATION_WARNINGS[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ Installation validation PASSED${NC}"
        echo
        echo "All checks completed successfully!"
        log "INFO" "Installation validation PASSED"
    else
        echo -e "${YELLOW}⚠ Installation validation PASSED with warnings${NC}"
        echo
        echo "Warnings (${#VALIDATION_WARNINGS[@]}):"
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} ${warning}"
        done
        log "INFO" "Installation validation PASSED with ${#VALIDATION_WARNINGS[@]} warnings"
    fi
    echo
    echo "Plugin is ready to use!"
    echo "Try: /bmad-ralph:init to get started"
else
    echo -e "${RED}✗ Installation validation FAILED${NC}"
    echo
    echo "Errors (${#VALIDATION_ERRORS[@]}):"
    for error in "${VALIDATION_ERRORS[@]}"; do
        echo -e "  ${RED}✗${NC} ${error}"
    done

    if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        echo
        echo "Warnings (${#VALIDATION_WARNINGS[@]}):"
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} ${warning}"
        done
    fi

    log "ERROR" "Installation validation FAILED with ${#VALIDATION_ERRORS[@]} errors"

    echo
    echo -e "${BLUE}Repair Options:${NC}"
    echo "  1. Run repair script: ${PLUGIN_DIR}/hooks/install-repair.sh"
    echo "  2. Reinstall plugin: Remove and reinstall from marketplace"
    echo "  3. Check installation logs: ${VALIDATION_LOG}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Exit with appropriate code
if [[ "$VALIDATION_PASSED" == "true" ]]; then
    exit 0
else
    exit 1
fi
