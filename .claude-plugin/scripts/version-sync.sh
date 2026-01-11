#!/usr/bin/env bash
# Version Synchronization Script
# Ensures version consistency between package.json and plugin.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_JSON="$PROJECT_ROOT/package.json"
PLUGIN_JSON="$PROJECT_ROOT/.claude-plugin/plugin.json"

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

Synchronize version between package.json and plugin.json

OPTIONS:
    --check             Check if versions are in sync (exit 0 if synced, 1 if not)
    --from-package      Set plugin.json version from package.json
    --from-plugin       Set package.json version from plugin.json
    --set VERSION       Set both files to specified version
    --help              Show this help message

EXAMPLES:
    # Check if versions are synced
    $0 --check

    # Sync plugin.json from package.json
    $0 --from-package

    # Set both to version 1.2.0
    $0 --set 1.2.0

EOF
    exit 1
}

# Validate semver format
validate_semver() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        print_message "$RED" "Error: Invalid semver format: $version"
        print_message "$YELLOW" "Expected format: MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]"
        print_message "$YELLOW" "Examples: 1.0.0, 1.2.3-beta.1, 2.0.0+20130313144700"
        return 1
    fi
    return 0
}

# Get version from package.json
get_package_version() {
    jq -r '.version' "$PACKAGE_JSON"
}

# Get version from plugin.json
get_plugin_version() {
    jq -r '.version' "$PLUGIN_JSON"
}

# Set version in package.json
set_package_version() {
    local version="$1"
    local temp_file
    temp_file=$(mktemp)
    jq --arg version "$version" '.version = $version' "$PACKAGE_JSON" > "$temp_file"
    mv "$temp_file" "$PACKAGE_JSON"
}

# Set version in plugin.json
set_plugin_version() {
    local version="$1"
    local temp_file
    temp_file=$(mktemp)
    jq --arg version "$version" '.version = $version' "$PLUGIN_JSON" > "$temp_file"
    mv "$temp_file" "$PLUGIN_JSON"
}

# Check if versions are in sync
check_sync() {
    local package_version
    local plugin_version

    package_version=$(get_package_version)
    plugin_version=$(get_plugin_version)

    print_message "$BLUE" "Version Check:"
    echo "  package.json: $package_version"
    echo "  plugin.json:  $plugin_version"
    echo

    if [[ "$package_version" == "$plugin_version" ]]; then
        print_message "$GREEN" "✓ Versions are in sync"
        return 0
    else
        print_message "$RED" "✗ Versions are out of sync"
        return 1
    fi
}

# Sync from package.json to plugin.json
sync_from_package() {
    local package_version
    package_version=$(get_package_version)

    validate_semver "$package_version" || exit 1

    print_message "$BLUE" "Syncing version from package.json to plugin.json..."
    set_plugin_version "$package_version"
    print_message "$GREEN" "✓ Set plugin.json version to $package_version"
}

# Sync from plugin.json to package.json
sync_from_plugin() {
    local plugin_version
    plugin_version=$(get_plugin_version)

    validate_semver "$plugin_version" || exit 1

    print_message "$BLUE" "Syncing version from plugin.json to package.json..."
    set_package_version "$plugin_version"
    print_message "$GREEN" "✓ Set package.json version to $plugin_version"
}

# Set version in both files
set_version() {
    local version="$1"

    validate_semver "$version" || exit 1

    print_message "$BLUE" "Setting version to $version in both files..."
    set_package_version "$version"
    set_plugin_version "$version"
    print_message "$GREEN" "✓ Both files updated to version $version"
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
        --check)
            check_sync
            ;;
        --from-package)
            sync_from_package
            ;;
        --from-plugin)
            sync_from_plugin
            ;;
        --set)
            if [[ -z "${2:-}" ]]; then
                print_message "$RED" "Error: --set requires a version argument"
                usage
            fi
            set_version "$2"
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
