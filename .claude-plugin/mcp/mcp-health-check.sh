#!/usr/bin/env bash
# MCP Health Check - Verify Perplexity MCP server connectivity
# Part of BMAD Ralph Plugin - STORY-030

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MCP_CONFIG="$PLUGIN_ROOT/.mcp.json"

# Log file
LOG_DIR="ralph/logs"
LOG_FILE="$LOG_DIR/mcp-health.log"

# Functions
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  MCP Health Check - Perplexity Server${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_config_exists() {
    echo -n "Checking MCP configuration... "
    if [[ ! -f "$MCP_CONFIG" ]]; then
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${RED}Error: MCP configuration not found at $MCP_CONFIG${NC}"
        log "ERROR" "MCP configuration not found"
        return 1
    fi
    echo -e "${GREEN}✓ OK${NC}"
    log "INFO" "MCP configuration found"
    return 0
}

check_jq_available() {
    echo -n "Checking jq availability... "
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${RED}Error: jq is required but not installed${NC}"
        log "ERROR" "jq not available"
        return 1
    fi
    echo -e "${GREEN}✓ OK${NC}"
    log "INFO" "jq available"
    return 0
}

check_api_key() {
    echo -n "Checking API key... "
    if [[ -z "${PERPLEXITY_API_KEY:-}" ]]; then
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${RED}Error: PERPLEXITY_API_KEY environment variable not set${NC}"
        echo ""
        echo -e "${YELLOW}To fix this:${NC}"
        echo "  export PERPLEXITY_API_KEY='your-api-key-here'"
        echo "  # Add to ~/.zshrc or ~/.bashrc to make permanent"
        log "ERROR" "PERPLEXITY_API_KEY not set"
        return 1
    fi
    echo -e "${GREEN}✓ OK${NC}"
    log "INFO" "PERPLEXITY_API_KEY is set"
    return 0
}

check_npm_available() {
    echo -n "Checking npm/npx availability... "
    if ! command -v npx &> /dev/null; then
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${RED}Error: npx is required but not installed${NC}"
        echo -e "${YELLOW}Install Node.js from https://nodejs.org/${NC}"
        log "ERROR" "npx not available"
        return 1
    fi
    echo -e "${GREEN}✓ OK${NC}"
    log "INFO" "npx available"
    return 0
}

check_mcp_config_valid() {
    echo -n "Validating MCP configuration schema... "
    if ! jq empty "$MCP_CONFIG" 2>/dev/null; then
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${RED}Error: Invalid JSON in $MCP_CONFIG${NC}"
        log "ERROR" "Invalid MCP configuration JSON"
        return 1
    fi

    # Check required fields
    local required_fields=("servers.perplexity" "global_settings" "authentication")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$MCP_CONFIG" &>/dev/null; then
            echo -e "${RED}✗ FAILED${NC}"
            echo -e "${RED}Error: Missing required field: $field${NC}"
            log "ERROR" "Missing required field: $field"
            return 1
        fi
    done

    echo -e "${GREEN}✓ OK${NC}"
    log "INFO" "MCP configuration is valid"
    return 0
}

check_log_directory() {
    echo -n "Checking log directory... "
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        echo -e "${YELLOW}⚠ CREATED${NC}"
        log "INFO" "Created log directory: $LOG_DIR"
    else
        echo -e "${GREEN}✓ OK${NC}"
        log "INFO" "Log directory exists"
    fi
    return 0
}

check_mcp_server_package() {
    echo -n "Checking Perplexity MCP server package... "

    # Try to resolve the package (this will download if needed)
    if npx -y @anthropic-ai/mcp-server-perplexity --help &>/dev/null; then
        echo -e "${GREEN}✓ OK${NC}"
        log "INFO" "Perplexity MCP server package available"
        return 0
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        echo -e "${YELLOW}Package will be downloaded on first use via npx${NC}"
        log "WARN" "Perplexity MCP server package not cached"
        return 0
    fi
}

display_config_summary() {
    echo ""
    echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}Configuration Summary${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

    if [[ -f "$MCP_CONFIG" ]] && command -v jq &> /dev/null; then
        local timeout=$(jq -r '.servers.perplexity.timeout_seconds' "$MCP_CONFIG")
        local max_attempts=$(jq -r '.servers.perplexity.retry_policy.max_attempts' "$MCP_CONFIG")
        local rate_limit=$(jq -r '.servers.perplexity.rate_limiting.requests_per_minute' "$MCP_CONFIG")
        local cache_enabled=$(jq -r '.global_settings.cache_responses' "$MCP_CONFIG")
        local cache_ttl=$(jq -r '.global_settings.cache_ttl_seconds' "$MCP_CONFIG")

        echo "  Timeout: ${timeout}s"
        echo "  Max Retry Attempts: $max_attempts"
        echo "  Rate Limit: $rate_limit requests/minute"
        echo "  Cache Enabled: $cache_enabled"
        echo "  Cache TTL: ${cache_ttl}s"
    fi
    echo ""
}

main() {
    print_header

    local failed=0

    # Ensure log directory exists first
    check_log_directory || ((failed++))

    # Run all checks
    check_config_exists || ((failed++))
    check_jq_available || ((failed++))
    check_api_key || ((failed++))
    check_npm_available || ((failed++))
    check_mcp_config_valid || ((failed++))
    check_mcp_server_package || ((failed++))

    echo ""

    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✓ All health checks passed!${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        display_config_summary
        log "INFO" "Health check passed - all systems operational"
        return 0
    else
        echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ✗ Health check failed: $failed check(s) failed${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}Please fix the issues above and run the health check again.${NC}"
        log "ERROR" "Health check failed: $failed checks failed"
        return 1
    fi
}

# Run main
main "$@"
