#!/usr/bin/env bash
# MCP Credential Validator
# Validates MCP server credentials on plugin load
# SECURITY: Never logs credential values

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
MCP_CONFIG="$PLUGIN_DIR/.mcp.json"
CACHE_DIR="$PLUGIN_DIR/.ralph-cache"
CREDENTIALS_FILE="$CACHE_DIR/mcp-credentials.enc"
LOG_FILE="$CACHE_DIR/hooks.log"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Logging function (NEVER logs credential values)
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] [mcp-credential-validator] $message" >> "$LOG_FILE"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq not found, skipping MCP credential validation${NC}"
    log "WARN" "jq not available, skipping validation"
    exit 0
fi

# Check if MCP config exists
if [[ ! -f "$MCP_CONFIG" ]]; then
    echo -e "${YELLOW}Warning: MCP configuration not found at $MCP_CONFIG${NC}"
    log "WARN" "MCP config not found"
    exit 0
fi

log "INFO" "Starting MCP credential validation"

# Parse MCP config
VALIDATE_ON_STARTUP=$(jq -r '.authentication.validation.validate_on_startup // true' "$MCP_CONFIG")
FAIL_ON_MISSING=$(jq -r '.authentication.validation.fail_on_missing_credentials // false' "$MCP_CONFIG")
SHOW_WARNINGS=$(jq -r '.authentication.validation.show_credential_warnings // true' "$MCP_CONFIG")
REQUIRED_ENV_VARS=$(jq -r '.authentication.required_env_vars[]? // empty' "$MCP_CONFIG")

# Skip validation if disabled
if [[ "$VALIDATE_ON_STARTUP" != "true" ]]; then
    log "INFO" "Credential validation disabled in config"
    exit 0
fi

echo -e "${BLUE}=== MCP Credential Validation ===${NC}"

# Track validation status
MISSING_CREDENTIALS=()
VALIDATION_ERRORS=()

# Function to validate environment variable credential
validate_env_var() {
    local var_name="$1"

    # Check if environment variable is set
    if [[ -z "${!var_name:-}" ]]; then
        MISSING_CREDENTIALS+=("$var_name")
        log "ERROR" "Missing required credential: $var_name (value not logged for security)"
        return 1
    fi

    # Check if value is not empty
    if [[ "${!var_name}" == "" ]]; then
        MISSING_CREDENTIALS+=("$var_name")
        log "ERROR" "Empty credential value: $var_name"
        return 1
    fi

    # SECURITY: Never log the actual credential value
    log "INFO" "Credential validated: $var_name (value not logged)"
    return 0
}

# Function to check Claude Code credential store
check_claude_credential_store() {
    local credential_name="$1"

    # Claude Code credential store integration
    # This would integrate with Claude Code's secure credential storage
    # For now, we check if environment variable is set

    # Future enhancement: Use Claude Code CLI to retrieve credentials
    # claude config get-credential "$credential_name"

    log "INFO" "Checking credential store for: $credential_name"

    # Check environment variable as fallback
    if [[ -n "${!credential_name:-}" ]]; then
        log "INFO" "Credential found in environment: $credential_name"
        return 0
    fi

    # Check encrypted credentials file
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        log "INFO" "Checking encrypted credentials file for: $credential_name"
        # Would decrypt and check here
        # For now, return not found
    fi

    log "WARN" "Credential not found in credential store: $credential_name"
    return 1
}

# Function to encrypt credential at rest (placeholder for future enhancement)
encrypt_credential() {
    local credential_name="$1"
    local credential_value="$2"

    # SECURITY NOTE: This is a placeholder for credential encryption
    # In production, this would use:
    # - Claude Code's credential store API
    # - OS keychain integration (Keychain on macOS, Credential Manager on Windows)
    # - GPG encryption with user's key

    log "INFO" "Encrypting credential: $credential_name (value not logged)"

    # For now, we just document the requirement
    # Future implementation would:
    # 1. Encrypt the credential using OS keychain or GPG
    # 2. Store encrypted value in $CREDENTIALS_FILE
    # 3. Set file permissions to 600 (owner read/write only)

    echo -e "${YELLOW}Note: Credential encryption at rest requires manual setup${NC}"
    echo -e "${YELLOW}Please use Claude Code credential store or OS keychain${NC}"
}

# Validate all required credentials
echo -e "${BLUE}Validating credentials...${NC}"

for env_var in $REQUIRED_ENV_VARS; do
    echo -n "  Checking $env_var... "

    if validate_env_var "$env_var"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"

        # Provide clear error message
        if [[ "$SHOW_WARNINGS" == "true" ]]; then
            echo -e "${RED}Error: $env_var is not set${NC}"
            echo -e "${YELLOW}Solution:${NC}"
            echo -e "  1. Set environment variable:"
            echo -e "     export $env_var=\"your-api-key-here\""
            echo -e "  2. Add to your shell profile (~/.zshrc or ~/.bashrc)"
            echo -e "  3. Or use Claude Code credential store"
            echo -e "  4. Reload your shell: source ~/.zshrc"
        fi
    fi
done

# Check Claude Code credential store (if available)
echo -e "\n${BLUE}Checking Claude Code credential store...${NC}"
for env_var in $REQUIRED_ENV_VARS; do
    if check_claude_credential_store "$env_var"; then
        echo -e "  $env_var: ${GREEN}Available${NC}"
    else
        echo -e "  $env_var: ${YELLOW}Not in credential store${NC}"
    fi
done

# Summary
echo -e "\n${BLUE}=== Validation Summary ===${NC}"

if [[ ${#MISSING_CREDENTIALS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ All credentials validated successfully${NC}"
    log "INFO" "All MCP credentials validated"
    exit 0
else
    echo -e "${RED}✗ Missing credentials: ${#MISSING_CREDENTIALS[@]}${NC}"
    for cred in "${MISSING_CREDENTIALS[@]}"; do
        echo -e "  - ${RED}$cred${NC}"
    done

    log "ERROR" "Missing credentials count: ${#MISSING_CREDENTIALS[@]}"

    if [[ "$FAIL_ON_MISSING" == "true" ]]; then
        echo -e "\n${RED}ERROR: Plugin load failed due to missing credentials${NC}"
        echo -e "${YELLOW}Set fail_on_missing_credentials: false in .mcp.json to continue without MCP${NC}"
        exit 1
    else
        echo -e "\n${YELLOW}Warning: MCP will not be available without valid credentials${NC}"
        echo -e "${YELLOW}Loop execution will continue with built-in agent knowledge${NC}"
        log "WARN" "Continuing without MCP due to missing credentials"
        exit 0
    fi
fi
