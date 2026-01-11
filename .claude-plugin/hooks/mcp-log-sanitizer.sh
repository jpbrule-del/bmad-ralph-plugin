#!/usr/bin/env bash
# MCP Log Sanitizer
# Ensures credentials are never logged in plain text
# Sanitizes logs by redacting sensitive information

set -euo pipefail

# Patterns to redact (regex patterns for sensitive data)
declare -a REDACT_PATTERNS=(
    # API Keys (various formats)
    "PERPLEXITY_API_KEY=[^[:space:]]*"
    "API_KEY=[^[:space:]]*"
    "api[_-]?key[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_-]{20,}[\"']?"

    # Tokens
    "Bearer [A-Za-z0-9_.-]+"
    "token[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_-]{20,}[\"']?"

    # Passwords
    "password[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[^[:space:]\"']+[\"']?"

    # Secrets
    "secret[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[^[:space:]\"']+[\"']?"

    # Private keys
    "-----BEGIN [A-Z ]+ PRIVATE KEY-----[^-]+-----END [A-Z ]+ PRIVATE KEY-----"

    # Authorization headers
    "Authorization:[[:space:]]*[^[:space:]]+"
)

# Replacement text for redacted content
REDACTED="[REDACTED]"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage
usage() {
    cat << EOF
MCP Log Sanitizer

Usage: $0 <command> [options]

Commands:
  sanitize <file>         Sanitize a log file in place
  check <file>            Check if file contains credentials (non-destructive)
  scan <directory>        Scan directory for files with credentials
  watch <file>            Watch and sanitize file in real-time
  help                    Show this help message

Examples:
  # Sanitize a log file
  $0 sanitize ralph/logs/mcp-usage.log

  # Check if file contains credentials
  $0 check ralph/logs/mcp-usage.log

  # Scan directory for unsanitized logs
  $0 scan ralph/logs/

  # Watch and sanitize in real-time
  $0 watch ralph/logs/mcp-usage.log

EOF
}

# Sanitize a single line
sanitize_line() {
    local line="$1"
    local sanitized="$line"

    for pattern in "${REDACT_PATTERNS[@]}"; do
        # Use sed to replace pattern with [REDACTED]
        sanitized=$(echo "$sanitized" | sed -E "s/$pattern/$REDACTED/g")
    done

    echo "$sanitized"
}

# Sanitize a file in place
sanitize_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File not found: $file${NC}"
        return 1
    fi

    echo -e "${BLUE}Sanitizing: $file${NC}"

    # Create backup
    local backup="$file.bak"
    cp "$file" "$backup"

    # Sanitize line by line
    local temp_file
    temp_file=$(mktemp)
    local redacted_count=0

    while IFS= read -r line; do
        local sanitized
        sanitized=$(sanitize_line "$line")

        # Count redactions
        if [[ "$sanitized" != "$line" ]]; then
            ((redacted_count++))
        fi

        echo "$sanitized" >> "$temp_file"
    done < "$file"

    # Replace original file
    mv "$temp_file" "$file"

    if [[ $redacted_count -gt 0 ]]; then
        echo -e "${YELLOW}✓ Sanitized $redacted_count lines${NC}"
        echo -e "${GREEN}✓ Backup saved: $backup${NC}"
    else
        echo -e "${GREEN}✓ No credentials found${NC}"
        rm -f "$backup"
    fi

    return 0
}

# Check if file contains credentials (non-destructive)
check_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File not found: $file${NC}"
        return 1
    fi

    echo -e "${BLUE}Checking: $file${NC}"

    local found_count=0
    local line_number=0

    while IFS= read -r line; do
        ((line_number++))

        for pattern in "${REDACT_PATTERNS[@]}"; do
            if echo "$line" | grep -qE "$pattern"; then
                ((found_count++))
                echo -e "${YELLOW}Line $line_number: Potential credential found${NC}"
                # Don't show the actual line (security)
                break
            fi
        done
    done < "$file"

    if [[ $found_count -gt 0 ]]; then
        echo -e "${RED}✗ Found $found_count potential credentials${NC}"
        echo -e "${YELLOW}Run: $0 sanitize $file${NC}"
        return 1
    else
        echo -e "${GREEN}✓ No credentials found${NC}"
        return 0
    fi
}

# Scan directory for files with credentials
scan_directory() {
    local directory="$1"

    if [[ ! -d "$directory" ]]; then
        echo -e "${RED}Error: Directory not found: $directory${NC}"
        return 1
    fi

    echo -e "${BLUE}Scanning directory: $directory${NC}"

    local total_files=0
    local files_with_credentials=0

    # Find all log files
    while IFS= read -r file; do
        ((total_files++))

        if ! check_file "$file" > /dev/null 2>&1; then
            ((files_with_credentials++))
            echo -e "${RED}✗ $file${NC}"
        else
            echo -e "${GREEN}✓ $file${NC}"
        fi
    done < <(find "$directory" -type f \( -name "*.log" -o -name "*.txt" \))

    echo -e "\n${BLUE}=== Scan Summary ===${NC}"
    echo -e "Total files: $total_files"
    echo -e "Files with credentials: ${RED}$files_with_credentials${NC}"
    echo -e "Clean files: ${GREEN}$((total_files - files_with_credentials))${NC}"

    if [[ $files_with_credentials -gt 0 ]]; then
        echo -e "\n${YELLOW}Recommendation: Run sanitize on files with credentials${NC}"
        return 1
    fi

    return 0
}

# Watch and sanitize file in real-time
watch_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo -e "${YELLOW}Warning: File not found, waiting for creation: $file${NC}"
        # Create file if it doesn't exist
        touch "$file"
    fi

    echo -e "${BLUE}Watching: $file${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"

    # Use tail -f to watch file and sanitize new lines
    tail -f "$file" | while IFS= read -r line; do
        local sanitized
        sanitized=$(sanitize_line "$line")

        # If line was sanitized, update the file
        if [[ "$sanitized" != "$line" ]]; then
            echo -e "${YELLOW}[SANITIZED] ${sanitized}${NC}"

            # Update file (replace last line)
            local temp_file
            temp_file=$(mktemp)
            head -n -1 "$file" > "$temp_file"
            echo "$sanitized" >> "$temp_file"
            mv "$temp_file" "$file"
        fi
    done
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
        sanitize)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}Error: Missing file path${NC}"
                echo "Usage: $0 sanitize <file>"
                exit 1
            fi
            sanitize_file "$1"
            ;;

        check)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}Error: Missing file path${NC}"
                echo "Usage: $0 check <file>"
                exit 1
            fi
            check_file "$1"
            ;;

        scan)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}Error: Missing directory path${NC}"
                echo "Usage: $0 scan <directory>"
                exit 1
            fi
            scan_directory "$1"
            ;;

        watch)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}Error: Missing file path${NC}"
                echo "Usage: $0 watch <file>"
                exit 1
            fi
            watch_file "$1"
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
