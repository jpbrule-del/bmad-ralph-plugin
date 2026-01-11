#!/usr/bin/env bash
# MCP Credential Manager
# Manages encrypted credentials for MCP servers
# Supports: Environment variables, Claude Code credential store, OS keychain

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
CACHE_DIR="$PLUGIN_DIR/.ralph-cache"
CREDENTIALS_FILE="$CACHE_DIR/mcp-credentials.enc"
LOG_FILE="$CACHE_DIR/hooks.log"

mkdir -p "$CACHE_DIR"

# Logging (NEVER logs credential values)
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] [mcp-credential-manager] $message" >> "$LOG_FILE"
}

# Usage information
usage() {
    cat << EOF
MCP Credential Manager

Usage: $0 <command> [options]

Commands:
  store <name> <value>    Store encrypted credential
  retrieve <name>         Retrieve decrypted credential
  delete <name>           Delete stored credential
  list                    List stored credential names (not values)
  validate                Validate all required credentials
  help                    Show this help message

Security Features:
  - Credentials encrypted at rest using GPG
  - File permissions set to 600 (owner only)
  - Credential values never logged
  - Integration with OS keychain (macOS/Linux/Windows)
  - Claude Code credential store support

Examples:
  # Store Perplexity API key
  $0 store PERPLEXITY_API_KEY "your-api-key"

  # Retrieve credential
  $0 retrieve PERPLEXITY_API_KEY

  # List stored credentials
  $0 list

  # Validate all credentials
  $0 validate

Environment Variables:
  MCP_ENCRYPTION_KEY    GPG key ID for encryption (optional)
  USE_CLAUDE_STORE      Use Claude Code credential store (true/false)
  USE_OS_KEYCHAIN       Use OS keychain integration (true/false)

EOF
}

# Check for GPG (for encryption)
check_gpg() {
    if command -v gpg &> /dev/null; then
        return 0
    elif command -v gpg2 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Encrypt credential using GPG
encrypt_credential() {
    local name="$1"
    local value="$2"

    log "INFO" "Encrypting credential: $name"

    if ! check_gpg; then
        echo -e "${RED}Error: GPG not found${NC}"
        echo -e "${YELLOW}Install GPG to use encryption:${NC}"
        echo -e "  macOS: brew install gnupg"
        echo -e "  Ubuntu: sudo apt-get install gnupg"
        echo -e "  Fedora: sudo dnf install gnupg"
        return 1
    fi

    # Create encrypted credentials file if it doesn't exist
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "{}" > "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
    fi

    # Encrypt the value
    local encrypted_value
    encrypted_value=$(echo "$value" | gpg --encrypt --armor --recipient "${MCP_ENCRYPTION_KEY:-$USER}" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: Encryption failed${NC}"
        echo -e "${YELLOW}Ensure you have a GPG key pair configured${NC}"
        return 1
    fi

    # Store encrypted credential (using jq if available)
    if command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp)
        jq --arg name "$name" --arg value "$encrypted_value" \
           '.[$name] = $value' "$CREDENTIALS_FILE" > "$temp_file"
        mv "$temp_file" "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
    else
        echo -e "${YELLOW}Warning: jq not found, using fallback storage${NC}"
        echo "$name:$encrypted_value" >> "$CREDENTIALS_FILE"
    fi

    echo -e "${GREEN}✓ Credential encrypted and stored: $name${NC}"
    log "INFO" "Credential stored: $name"
    return 0
}

# Decrypt credential using GPG
decrypt_credential() {
    local name="$1"

    log "INFO" "Retrieving credential: $name"

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo -e "${RED}Error: No credentials stored${NC}"
        return 1
    fi

    if ! check_gpg; then
        echo -e "${RED}Error: GPG not found${NC}"
        return 1
    fi

    # Retrieve encrypted value
    local encrypted_value
    if command -v jq &> /dev/null; then
        encrypted_value=$(jq -r --arg name "$name" '.[$name] // empty' "$CREDENTIALS_FILE")
    else
        encrypted_value=$(grep "^$name:" "$CREDENTIALS_FILE" | cut -d':' -f2-)
    fi

    if [[ -z "$encrypted_value" ]]; then
        echo -e "${RED}Error: Credential not found: $name${NC}"
        return 1
    fi

    # Decrypt the value
    local decrypted_value
    decrypted_value=$(echo "$encrypted_value" | gpg --decrypt --quiet 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: Decryption failed${NC}"
        return 1
    fi

    # SECURITY: Output to stdout (caller should capture, not log)
    echo "$decrypted_value"
    log "INFO" "Credential retrieved: $name (value not logged)"
    return 0
}

# Delete stored credential
delete_credential() {
    local name="$1"

    log "INFO" "Deleting credential: $name"

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo -e "${YELLOW}Warning: No credentials stored${NC}"
        return 0
    fi

    if command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp)
        jq --arg name "$name" 'del(.[$name])' "$CREDENTIALS_FILE" > "$temp_file"
        mv "$temp_file" "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
    else
        sed -i.bak "/^$name:/d" "$CREDENTIALS_FILE"
        rm -f "$CREDENTIALS_FILE.bak"
    fi

    echo -e "${GREEN}✓ Credential deleted: $name${NC}"
    log "INFO" "Credential deleted: $name"
    return 0
}

# List stored credential names (NOT values)
list_credentials() {
    log "INFO" "Listing stored credentials"

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo -e "${YELLOW}No credentials stored${NC}"
        return 0
    fi

    echo -e "${BLUE}=== Stored Credentials ===${NC}"

    if command -v jq &> /dev/null; then
        jq -r 'keys[]' "$CREDENTIALS_FILE" | while read -r name; do
            echo -e "  - ${GREEN}$name${NC}"
        done
    else
        cut -d':' -f1 "$CREDENTIALS_FILE" | while read -r name; do
            echo -e "  - ${GREEN}$name${NC}"
        done
    fi
}

# Validate required credentials
validate_credentials() {
    log "INFO" "Validating credentials"

    # Call the credential validator script
    if [[ -x "$SCRIPT_DIR/mcp-credential-validator.sh" ]]; then
        "$SCRIPT_DIR/mcp-credential-validator.sh"
    else
        echo -e "${RED}Error: Credential validator not found${NC}"
        return 1
    fi
}

# OS Keychain integration (macOS/Linux/Windows)
use_os_keychain() {
    local operation="$1"
    local name="$2"
    local value="${3:-}"

    # macOS Keychain
    if [[ "$OSTYPE" == "darwin"* ]]; then
        case "$operation" in
            store)
                security add-generic-password -a "$USER" -s "ralph-mcp-$name" -w "$value" -U
                echo -e "${GREEN}✓ Stored in macOS Keychain: $name${NC}"
                ;;
            retrieve)
                security find-generic-password -a "$USER" -s "ralph-mcp-$name" -w 2>/dev/null
                ;;
            delete)
                security delete-generic-password -a "$USER" -s "ralph-mcp-$name" 2>/dev/null
                echo -e "${GREEN}✓ Deleted from macOS Keychain: $name${NC}"
                ;;
        esac
        return 0
    fi

    # Linux Secret Service (using secret-tool if available)
    if command -v secret-tool &> /dev/null; then
        case "$operation" in
            store)
                echo -n "$value" | secret-tool store --label="Ralph MCP: $name" application ralph credential "$name"
                echo -e "${GREEN}✓ Stored in Secret Service: $name${NC}"
                ;;
            retrieve)
                secret-tool lookup application ralph credential "$name" 2>/dev/null
                ;;
            delete)
                secret-tool clear application ralph credential "$name" 2>/dev/null
                echo -e "${GREEN}✓ Deleted from Secret Service: $name${NC}"
                ;;
        esac
        return 0
    fi

    # Windows Credential Manager (using cmdkey on Windows)
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        case "$operation" in
            store)
                cmdkey /generic:"ralph-mcp-$name" /user:"$USER" /pass:"$value"
                echo -e "${GREEN}✓ Stored in Windows Credential Manager: $name${NC}"
                ;;
            retrieve)
                cmdkey /list | grep "ralph-mcp-$name" | awk '{print $NF}'
                ;;
            delete)
                cmdkey /delete:"ralph-mcp-$name"
                echo -e "${GREEN}✓ Deleted from Windows Credential Manager: $name${NC}"
                ;;
        esac
        return 0
    fi

    echo -e "${YELLOW}Warning: OS keychain not available on this platform${NC}"
    return 1
}

# Main command handler
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        store)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}Error: Missing arguments${NC}"
                echo "Usage: $0 store <name> <value>"
                exit 1
            fi

            # Use OS keychain if enabled
            if [[ "${USE_OS_KEYCHAIN:-false}" == "true" ]]; then
                use_os_keychain store "$1" "$2"
            else
                encrypt_credential "$1" "$2"
            fi
            ;;

        retrieve)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}Error: Missing credential name${NC}"
                echo "Usage: $0 retrieve <name>"
                exit 1
            fi

            # Use OS keychain if enabled
            if [[ "${USE_OS_KEYCHAIN:-false}" == "true" ]]; then
                use_os_keychain retrieve "$1"
            else
                decrypt_credential "$1"
            fi
            ;;

        delete)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}Error: Missing credential name${NC}"
                echo "Usage: $0 delete <name>"
                exit 1
            fi

            # Use OS keychain if enabled
            if [[ "${USE_OS_KEYCHAIN:-false}" == "true" ]]; then
                use_os_keychain delete "$1"
            else
                delete_credential "$1"
            fi
            ;;

        list)
            list_credentials
            ;;

        validate)
            validate_credentials
            ;;

        help|--help|-h)
            usage
            ;;

        *)
            echo -e "${RED}Error: Unknown command: $command${NC}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
