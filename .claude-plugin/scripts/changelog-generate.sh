#!/usr/bin/env bash
# Changelog Generation Script
# Generates changelog entries following Keep a Changelog format
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"
MARKETPLACE_CHANGELOG="$PROJECT_ROOT/marketplace-repo/plugins/bmad-ralph/CHANGELOG.md"

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

Generate or update changelog following Keep a Changelog format

OPTIONS:
    --new VERSION       Create new changelog entry for VERSION
    --from-git VERSION  Generate changelog from git commits since last tag
    --validate          Validate changelog format
    --help              Show this help message

EXAMPLES:
    # Create new entry for version 1.2.0
    $0 --new 1.2.0

    # Generate from git commits
    $0 --from-git 1.2.0

    # Validate changelog format
    $0 --validate

CHANGELOG FORMAT:
    Follows Keep a Changelog (https://keepachangelog.com/en/1.0.0/)
    and Semantic Versioning (https://semver.org/spec/v2.0.0.html)

    Categories:
    - Added: New features
    - Changed: Changes in existing functionality
    - Deprecated: Soon-to-be removed features
    - Removed: Removed features
    - Fixed: Bug fixes
    - Security: Vulnerability fixes

EOF
    exit 1
}

# Validate semver format
validate_semver() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        print_message "$RED" "Error: Invalid semver format: $version"
        return 1
    fi
    return 0
}

# Create changelog if it doesn't exist
init_changelog() {
    if [[ ! -f "$CHANGELOG" ]]; then
        cat > "$CHANGELOG" << 'EOF'
# Changelog

All notable changes to the BMAD Ralph Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

EOF
        print_message "$GREEN" "✓ Created new CHANGELOG.md"
    fi
}

# Create new changelog entry
create_entry() {
    local version="$1"
    local date
    date=$(date +%Y-%m-%d)

    validate_semver "$version" || exit 1
    init_changelog

    # Check if version already exists
    if grep -q "## \[$version\]" "$CHANGELOG"; then
        print_message "$RED" "Error: Version $version already exists in changelog"
        exit 1
    fi

    # Create new entry by replacing [Unreleased] section
    local temp_file
    temp_file=$(mktemp)

    # Read the changelog and insert new version
    awk -v version="$version" -v date="$date" '
        /## \[Unreleased\]/ {
            print $0
            print ""
            print "### Added"
            print ""
            print "### Changed"
            print ""
            print "### Deprecated"
            print ""
            print "### Removed"
            print ""
            print "### Fixed"
            print ""
            print "### Security"
            print ""
            print "## [" version "] - " date
            unreleased_found = 1
            next
        }
        unreleased_found && /^### / {
            # Skip empty sections in unreleased
            section = $0
            getline
            if ($0 !~ /^$/) {
                print section
                print $0
            }
            next
        }
        { print }
    ' "$CHANGELOG" > "$temp_file"

    mv "$temp_file" "$CHANGELOG"

    print_message "$GREEN" "✓ Created changelog entry for version $version"
    print_message "$YELLOW" "📝 Please edit CHANGELOG.md to add release notes"
}

# Generate changelog from git commits
generate_from_git() {
    local version="$1"
    local last_tag
    local commits

    validate_semver "$version" || exit 1
    init_changelog

    # Get last tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [[ -z "$last_tag" ]]; then
        print_message "$YELLOW" "No previous tags found, using all commits"
        commits=$(git log --oneline --no-merges)
    else
        print_message "$BLUE" "Generating changelog from $last_tag to HEAD"
        commits=$(git log "$last_tag..HEAD" --oneline --no-merges)
    fi

    # Parse commits by type
    local added=()
    local changed=()
    local fixed=()
    local removed=()
    local security=()
    local other=()

    while IFS= read -r commit; do
        if [[ -z "$commit" ]]; then
            continue
        fi

        # Parse conventional commit format: type(scope): message
        if [[ "$commit" =~ ^[a-f0-9]+\ (feat|feature)(\([^)]+\))?:\ (.+)$ ]]; then
            added+=("- ${BASH_REMATCH[3]}")
        elif [[ "$commit" =~ ^[a-f0-9]+\ (fix|bugfix)(\([^)]+\))?:\ (.+)$ ]]; then
            fixed+=("- ${BASH_REMATCH[3]}")
        elif [[ "$commit" =~ ^[a-f0-9]+\ (refactor|perf|style|chore)(\([^)]+\))?:\ (.+)$ ]]; then
            changed+=("- ${BASH_REMATCH[3]}")
        elif [[ "$commit" =~ ^[a-f0-9]+\ (remove|delete)(\([^)]+\))?:\ (.+)$ ]]; then
            removed+=("- ${BASH_REMATCH[3]}")
        elif [[ "$commit" =~ ^[a-f0-9]+\ (security|sec)(\([^)]+\))?:\ (.+)$ ]]; then
            security+=("- ${BASH_REMATCH[3]}")
        else
            # Extract just the message part (after commit hash)
            local msg
            msg=$(echo "$commit" | sed 's/^[a-f0-9]* //')
            other+=("- $msg")
        fi
    done <<< "$commits"

    # Create changelog entry
    local date
    date=$(date +%Y-%m-%d)
    local temp_file
    temp_file=$(mktemp)

    {
        echo "# Changelog"
        echo ""
        echo "All notable changes to the BMAD Ralph Plugin will be documented in this file."
        echo ""
        echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),"
        echo "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)."
        echo ""
        echo "## [Unreleased]"
        echo ""
        echo "## [$version] - $date"
        echo ""

        if [[ ${#added[@]} -gt 0 ]]; then
            echo "### Added"
            echo ""
            printf '%s\n' "${added[@]}"
            echo ""
        fi

        if [[ ${#changed[@]} -gt 0 ]]; then
            echo "### Changed"
            echo ""
            printf '%s\n' "${changed[@]}"
            echo ""
        fi

        if [[ ${#fixed[@]} -gt 0 ]]; then
            echo "### Fixed"
            echo ""
            printf '%s\n' "${fixed[@]}"
            echo ""
        fi

        if [[ ${#removed[@]} -gt 0 ]]; then
            echo "### Removed"
            echo ""
            printf '%s\n' "${removed[@]}"
            echo ""
        fi

        if [[ ${#security[@]} -gt 0 ]]; then
            echo "### Security"
            echo ""
            printf '%s\n' "${security[@]}"
            echo ""
        fi

        if [[ ${#other[@]} -gt 0 ]]; then
            echo "### Other"
            echo ""
            printf '%s\n' "${other[@]}"
            echo ""
        fi

        # Append existing entries (skip header and unreleased)
        if [[ -f "$CHANGELOG" ]]; then
            awk '/## \[[0-9]/ { found=1 } found { print }' "$CHANGELOG"
        fi
    } > "$temp_file"

    mv "$temp_file" "$CHANGELOG"

    print_message "$GREEN" "✓ Generated changelog from git commits"
    print_message "$YELLOW" "📝 Review and edit CHANGELOG.md before release"
}

# Validate changelog format
validate_changelog() {
    if [[ ! -f "$CHANGELOG" ]]; then
        print_message "$RED" "Error: CHANGELOG.md not found"
        exit 1
    fi

    local errors=0

    # Check for required headers
    if ! grep -q "# Changelog" "$CHANGELOG"; then
        print_message "$RED" "✗ Missing '# Changelog' header"
        ((errors++))
    fi

    if ! grep -q "Keep a Changelog" "$CHANGELOG"; then
        print_message "$RED" "✗ Missing Keep a Changelog reference"
        ((errors++))
    fi

    if ! grep -q "Semantic Versioning" "$CHANGELOG"; then
        print_message "$RED" "✗ Missing Semantic Versioning reference"
        ((errors++))
    fi

    if ! grep -q "## \[Unreleased\]" "$CHANGELOG"; then
        print_message "$RED" "✗ Missing [Unreleased] section"
        ((errors++))
    fi

    # Check version format
    local invalid_versions
    invalid_versions=$(grep -E "^## \[[0-9]" "$CHANGELOG" | grep -Ev "^## \[[0-9]+\.[0-9]+\.[0-9]+.*\] - [0-9]{4}-[0-9]{2}-[0-9]{2}")

    if [[ -n "$invalid_versions" ]]; then
        print_message "$RED" "✗ Invalid version format found:"
        echo "$invalid_versions"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        print_message "$GREEN" "✓ Changelog format is valid"
        return 0
    else
        print_message "$RED" "✗ Found $errors error(s) in changelog"
        return 1
    fi
}

# Sync to marketplace changelog
sync_to_marketplace() {
    if [[ -f "$CHANGELOG" ]] && [[ -d "$(dirname "$MARKETPLACE_CHANGELOG")" ]]; then
        cp "$CHANGELOG" "$MARKETPLACE_CHANGELOG"
        print_message "$GREEN" "✓ Synced changelog to marketplace"
    fi
}

# Main script logic
main() {
    # Parse arguments
    case "${1:-}" in
        --new)
            if [[ -z "${2:-}" ]]; then
                print_message "$RED" "Error: --new requires a version argument"
                usage
            fi
            create_entry "$2"
            sync_to_marketplace
            ;;
        --from-git)
            if [[ -z "${2:-}" ]]; then
                print_message "$RED" "Error: --from-git requires a version argument"
                usage
            fi
            generate_from_git "$2"
            sync_to_marketplace
            ;;
        --validate)
            validate_changelog
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
