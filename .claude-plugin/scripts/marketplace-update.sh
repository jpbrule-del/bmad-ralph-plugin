#!/usr/bin/env bash
# Marketplace Update Script
# Updates marketplace manifest and index after release
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MARKETPLACE_DIR="$PROJECT_ROOT/marketplace-repo"
MARKETPLACE_INDEX="$MARKETPLACE_DIR/marketplace-index.json"
PLUGIN_DIR="$MARKETPLACE_DIR/plugins/bmad-ralph"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Update marketplace manifest and index for BMAD Ralph Plugin

OPTIONS:
    --sync              Sync all files to marketplace
    --update-index      Update marketplace index with current version
    --validate          Validate marketplace files
    --help              Show this help message

EXAMPLES:
    # Sync all files to marketplace
    $0 --sync

    # Update marketplace index
    $0 --update-index

    # Validate marketplace files
    $0 --validate

EOF
    exit 1
}

# Get current plugin version
get_plugin_version() {
    jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json"
}

# Sync files to marketplace
sync_to_marketplace() {
    print_message "$BLUE" "Syncing files to marketplace..."

    if [[ ! -d "$MARKETPLACE_DIR" ]]; then
        print_message "$YELLOW" "Warning: Marketplace directory not found"
        return 1
    fi

    # Sync plugin.json
    if [[ -f "$PROJECT_ROOT/.claude-plugin/plugin.json" ]]; then
        cp "$PROJECT_ROOT/.claude-plugin/plugin.json" "$PLUGIN_DIR/plugin.json"
        print_message "$GREEN" "✓ Synced plugin.json"
    fi

    # Sync marketplace.json
    if [[ -f "$PROJECT_ROOT/.claude-plugin/marketplace.json" ]]; then
        cp "$PROJECT_ROOT/.claude-plugin/marketplace.json" "$PLUGIN_DIR/marketplace.json"
        print_message "$GREEN" "✓ Synced marketplace.json"
    fi

    # Sync CHANGELOG.md
    if [[ -f "$PROJECT_ROOT/CHANGELOG.md" ]]; then
        cp "$PROJECT_ROOT/CHANGELOG.md" "$PLUGIN_DIR/CHANGELOG.md"
        print_message "$GREEN" "✓ Synced CHANGELOG.md"
    fi

    # Sync README.md
    if [[ -f "$PROJECT_ROOT/README.md" ]]; then
        cp "$PROJECT_ROOT/README.md" "$PLUGIN_DIR/README.md"
        print_message "$GREEN" "✓ Synced README.md"
    fi

    print_message "$GREEN" "✓ Marketplace files synced"
}

# Update marketplace index
update_index() {
    print_message "$BLUE" "Updating marketplace index..."

    if [[ ! -f "$MARKETPLACE_INDEX" ]]; then
        print_message "$YELLOW" "Warning: Marketplace index not found"
        return 1
    fi

    local version
    version=$(get_plugin_version)

    local temp_file
    temp_file=$(mktemp)

    # Update version and last_updated in marketplace index
    jq --arg version "$version" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        .plugins[] |= if .id == "bmad-ralph" then
            .version = $version |
            .last_updated = $date
        else . end
    ' "$MARKETPLACE_INDEX" > "$temp_file"

    mv "$temp_file" "$MARKETPLACE_INDEX"

    print_message "$GREEN" "✓ Marketplace index updated to version $version"
}

# Validate marketplace files
validate_marketplace() {
    print_message "$BLUE" "Validating marketplace files..."

    local errors=0

    # Check if marketplace directory exists
    if [[ ! -d "$MARKETPLACE_DIR" ]]; then
        print_message "$RED" "✗ Marketplace directory not found: $MARKETPLACE_DIR"
        ((errors++))
    fi

    # Check marketplace index
    if [[ ! -f "$MARKETPLACE_INDEX" ]]; then
        print_message "$RED" "✗ Marketplace index not found: $MARKETPLACE_INDEX"
        ((errors++))
    else
        if ! jq empty "$MARKETPLACE_INDEX" 2>/dev/null; then
            print_message "$RED" "✗ Invalid JSON in marketplace index"
            ((errors++))
        else
            print_message "$GREEN" "✓ Marketplace index is valid JSON"
        fi
    fi

    # Check plugin directory
    if [[ ! -d "$PLUGIN_DIR" ]]; then
        print_message "$RED" "✗ Plugin directory not found: $PLUGIN_DIR"
        ((errors++))
    fi

    # Check plugin.json
    if [[ ! -f "$PLUGIN_DIR/plugin.json" ]]; then
        print_message "$RED" "✗ Plugin manifest not found in marketplace"
        ((errors++))
    else
        if ! jq empty "$PLUGIN_DIR/plugin.json" 2>/dev/null; then
            print_message "$RED" "✗ Invalid JSON in plugin manifest"
            ((errors++))
        else
            print_message "$GREEN" "✓ Plugin manifest is valid JSON"
        fi
    fi

    # Check marketplace.json
    if [[ ! -f "$PLUGIN_DIR/marketplace.json" ]]; then
        print_message "$RED" "✗ Marketplace manifest not found"
        ((errors++))
    else
        if ! jq empty "$PLUGIN_DIR/marketplace.json" 2>/dev/null; then
            print_message "$RED" "✗ Invalid JSON in marketplace manifest"
            ((errors++))
        else
            print_message "$GREEN" "✓ Marketplace manifest is valid JSON"
        fi
    fi

    # Check CHANGELOG.md
    if [[ ! -f "$PLUGIN_DIR/CHANGELOG.md" ]]; then
        print_message "$YELLOW" "⚠ CHANGELOG.md not found in marketplace"
    else
        print_message "$GREEN" "✓ CHANGELOG.md exists"
    fi

    # Check README.md
    if [[ ! -f "$PLUGIN_DIR/README.md" ]]; then
        print_message "$YELLOW" "⚠ README.md not found in marketplace"
    else
        print_message "$GREEN" "✓ README.md exists"
    fi

    # Verify version consistency
    local plugin_version
    local marketplace_version
    local index_version

    plugin_version=$(jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "")
    marketplace_version=$(jq -r '.version' "$PLUGIN_DIR/plugin.json" 2>/dev/null || echo "")
    index_version=$(jq -r '.plugins[] | select(.id == "bmad-ralph") | .version' "$MARKETPLACE_INDEX" 2>/dev/null || echo "")

    if [[ -n "$plugin_version" ]] && [[ -n "$marketplace_version" ]] && [[ -n "$index_version" ]]; then
        if [[ "$plugin_version" == "$marketplace_version" ]] && [[ "$marketplace_version" == "$index_version" ]]; then
            print_message "$GREEN" "✓ Version consistency: $plugin_version"
        else
            print_message "$RED" "✗ Version mismatch:"
            echo "  Plugin: $plugin_version"
            echo "  Marketplace: $marketplace_version"
            echo "  Index: $index_version"
            ((errors++))
        fi
    fi

    if [[ $errors -eq 0 ]]; then
        print_message "$GREEN" "✓ Marketplace validation passed"
        return 0
    else
        print_message "$RED" "✗ Found $errors error(s) in marketplace"
        return 1
    fi
}

# Main script logic
main() {
    # Check dependencies
    if ! command -v jq &> /dev/null; then
        print_message "$RED" "Error: jq is required but not installed"
        exit 1
    fi

    # Parse arguments
    case "${1:-}" in
        --sync)
            sync_to_marketplace
            ;;
        --update-index)
            update_index
            ;;
        --validate)
            validate_marketplace
            ;;
        --help|"")
            usage
            ;;
        *)
            print_message "$RED" "Error: Unknown option: $1"
            usage
            ;;
    esac
}

main "$@"
