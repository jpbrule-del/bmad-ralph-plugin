#!/usr/bin/env bash
# Version Rollback Script
# Safely rollback to a previous version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
Usage: $0 [OPTIONS] VERSION

Rollback BMAD Ralph Plugin to a previous version

OPTIONS:
    --list              List available versions from git tags
    --dry-run           Preview rollback without making changes
    --force             Skip confirmation prompts
    --help              Show this help message

ARGUMENTS:
    VERSION             Version to rollback to (e.g., 1.0.0, v1.0.0)

EXAMPLES:
    # List available versions
    $0 --list

    # Rollback to version 1.0.0
    $0 1.0.0

    # Dry run to preview changes
    $0 --dry-run 1.0.0

ROLLBACK PROCESS:
    1. Validate target version exists in git tags
    2. Create backup branch
    3. Reset to target version tag
    4. Update version files
    5. Create rollback commit
    6. Optionally push to remote

SAFETY:
    - Creates backup branch before rollback
    - Requires clean working directory
    - Prompts for confirmation (unless --force)
    - Can be dry-run to preview changes

EOF
    exit 1
}

# List available versions from git tags
list_versions() {
    print_message "$BLUE" "Available versions (from git tags):"
    echo

    if ! git tag -l "v*" | grep -q .; then
        print_message "$YELLOW" "No version tags found"
        return 0
    fi

    # List tags sorted by version
    git tag -l "v*" | sort -V | while read -r tag; do
        local version="${tag#v}"
        local date
        date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
        local commit
        commit=$(git rev-parse --short "$tag" 2>/dev/null)

        echo "  $version  ($date, commit $commit)"
    done

    echo
    print_message "$CYAN" "Current version: $(jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json")"
}

# Validate git repository state
validate_git_state() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_message "$RED" "Error: Not in a git repository"
        exit 1
    fi

    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain)" ]]; then
        print_message "$RED" "Error: Working directory has uncommitted changes"
        print_message "$YELLOW" "Please commit or stash changes before rollback"
        git status --short
        exit 1
    fi

    print_message "$GREEN" "✓ Git repository state is clean"
}

# Validate target version
validate_target_version() {
    local version="$1"

    # Remove 'v' prefix if present
    version="${version#v}"

    # Check if version tag exists
    if ! git rev-parse "v$version" >/dev/null 2>&1; then
        print_message "$RED" "Error: Version v$version does not exist in git tags"
        print_message "$YELLOW" "Run '$0 --list' to see available versions"
        exit 1
    fi

    print_message "$GREEN" "✓ Target version v$version exists"
    echo "$version"
}

# Create backup branch
create_backup() {
    local current_branch
    current_branch=$(git branch --show-current)
    local backup_branch="backup-before-rollback-$(date +%Y%m%d-%H%M%S)"
    local dry_run="$1"

    print_message "$BLUE" "Creating backup branch..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would create backup branch: $backup_branch"
    else
        git branch "$backup_branch"
        print_message "$GREEN" "✓ Created backup branch: $backup_branch"
        print_message "$YELLOW" "You can restore from this branch if needed:"
        echo "  git checkout $backup_branch"
    fi
}

# Rollback to version
rollback_to_version() {
    local version="$1"
    local dry_run="$2"

    print_message "$BLUE" "Rolling back to version $version..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would checkout tag v$version"
        return 0
    fi

    # Checkout the specific files from the tag
    local tag="v$version"

    # Reset version files to the tag
    git checkout "$tag" -- package.json .claude-plugin/plugin.json CHANGELOG.md 2>/dev/null || true

    # Also update marketplace if it exists
    if [[ -d "$PROJECT_ROOT/marketplace-repo" ]]; then
        git checkout "$tag" -- marketplace-repo/ 2>/dev/null || true
    fi

    print_message "$GREEN" "✓ Rolled back version files to $version"
}

# Verify rollback
verify_rollback() {
    local version="$1"

    print_message "$BLUE" "Verifying rollback..."

    local package_version
    local plugin_version

    package_version=$(jq -r '.version' "$PROJECT_ROOT/package.json")
    plugin_version=$(jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json")

    if [[ "$package_version" == "$version" ]] && [[ "$plugin_version" == "$version" ]]; then
        print_message "$GREEN" "✓ Rollback verified: versions are $version"
        return 0
    else
        print_message "$RED" "✗ Rollback verification failed"
        echo "  Expected: $version"
        echo "  package.json: $package_version"
        echo "  plugin.json: $plugin_version"
        return 1
    fi
}

# Commit rollback
commit_rollback() {
    local version="$1"
    local dry_run="$2"

    print_message "$BLUE" "Committing rollback..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would commit: rollback: revert to v$version"
    else
        git add package.json .claude-plugin/plugin.json CHANGELOG.md marketplace-repo/ 2>/dev/null || true
        git commit -m "rollback: revert to v$version

This rollback reverts the project to version $version.

To restore to a later version, use:
  git revert HEAD
  ./scripts/release.sh <newer-version>"
        print_message "$GREEN" "✓ Rollback committed"
    fi
}

# Push rollback
push_rollback() {
    local dry_run="$1"

    print_message "$BLUE" "Pushing rollback..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would push rollback to remote"
    else
        local current_branch
        current_branch=$(git branch --show-current)

        read -p "Push rollback to remote? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin "$current_branch"
            print_message "$GREEN" "✓ Rollback pushed to remote"
        else
            print_message "$YELLOW" "Skipped pushing to remote. You can push manually:"
            echo "  git push origin $current_branch"
        fi
    fi
}

# Display rollback summary
display_summary() {
    local version="$1"
    local dry_run="$2"

    echo
    print_message "$CYAN" "═══════════════════════════════════════"
    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "  DRY RUN ROLLBACK SUMMARY"
    else
        print_message "$GREEN" "  ROLLBACK COMPLETE!"
    fi
    print_message "$CYAN" "═══════════════════════════════════════"
    echo
    print_message "$BLUE" "Rolled back to version: $version"
    echo

    if [[ "$dry_run" == "false" ]]; then
        print_message "$YELLOW" "Important:"
        echo "  - A backup branch was created before rollback"
        echo "  - Review the changes before pushing to remote"
        echo "  - To undo this rollback: git revert HEAD"
        echo
        print_message "$GREEN" "Next steps:"
        echo "  1. Test the rolled-back version"
        echo "  2. Push to remote if everything looks good"
        echo "  3. Consider creating a new release if needed"
    else
        print_message "$YELLOW" "This was a dry run. No changes were made."
        print_message "$YELLOW" "Run without --dry-run to execute the rollback."
    fi
    echo
}

# Main script logic
main() {
    local version=""
    local dry_run="false"
    local force="false"
    local list_only="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list)
                list_only="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            --help)
                usage
                ;;
            -*)
                print_message "$RED" "Error: Unknown option: $1"
                usage
                ;;
            *)
                version="$1"
                shift
                ;;
        esac
    done

    # Check dependencies
    if ! command -v jq &> /dev/null; then
        print_message "$RED" "Error: jq is required but not installed"
        exit 1
    fi

    # Handle list-only mode
    if [[ "$list_only" == "true" ]]; then
        list_versions
        exit 0
    fi

    # Validate version argument
    if [[ -z "$version" ]]; then
        print_message "$RED" "Error: VERSION argument is required"
        usage
    fi

    # Start rollback process
    print_message "$CYAN" "╔═══════════════════════════════════════╗"
    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "║  Version Rollback (DRY RUN)          ║"
    else
        print_message "$CYAN" "║  Version Rollback                     ║"
    fi
    print_message "$CYAN" "╚═══════════════════════════════════════╝"
    echo

    # Step 1: Validate git state
    if [[ "$dry_run" == "false" ]]; then
        validate_git_state
    fi

    # Step 2: Validate target version
    version=$(validate_target_version "$version")

    # Step 3: Confirmation
    if [[ "$force" == "false" ]] && [[ "$dry_run" == "false" ]]; then
        print_message "$YELLOW" "Warning: This will rollback to version $version"
        read -p "Are you sure you want to continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message "$YELLOW" "Rollback cancelled"
            exit 0
        fi
    fi

    # Step 4: Create backup
    create_backup "$dry_run"

    # Step 5: Rollback to version
    rollback_to_version "$version" "$dry_run"

    # Step 6: Verify rollback
    if [[ "$dry_run" == "false" ]]; then
        verify_rollback "$version"
    fi

    # Step 7: Commit rollback
    commit_rollback "$version" "$dry_run"

    # Step 8: Push to remote
    if [[ "$dry_run" == "false" ]]; then
        push_rollback "$dry_run"
    fi

    # Display summary
    display_summary "$version" "$dry_run"
}

main "$@"
