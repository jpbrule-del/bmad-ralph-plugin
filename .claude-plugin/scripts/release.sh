#!/usr/bin/env bash
# Release Automation Script
# Automates the release process with version bumping, changelog, and git tagging
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

Automate the release process for BMAD Ralph Plugin

OPTIONS:
    --dry-run           Preview release without making changes
    --from-git          Generate changelog from git commits
    --skip-tests        Skip running tests before release
    --skip-marketplace  Skip marketplace update
    --help              Show this help message

ARGUMENTS:
    VERSION             Semver version (e.g., 1.2.0, 2.0.0-beta.1)

EXAMPLES:
    # Create release 1.2.0 (interactive)
    $0 1.2.0

    # Dry run to preview changes
    $0 --dry-run 1.2.0

    # Release with auto-generated changelog
    $0 --from-git 1.2.0

RELEASE PROCESS:
    1. Validate current state (clean git, tests pass)
    2. Bump version in package.json and plugin.json
    3. Update or generate changelog
    4. Commit version changes
    5. Create git tag
    6. Update marketplace manifest
    7. Push changes and tag

EOF
    exit 1
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
        print_message "$YELLOW" "Please commit or stash changes before releasing"
        git status --short
        exit 1
    fi

    # Check current branch
    local current_branch
    current_branch=$(git branch --show-current)
    print_message "$BLUE" "Current branch: $current_branch"

    # Warn if not on main/master
    if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
        print_message "$YELLOW" "Warning: Not on main/master branch"
        read -p "Continue with release on $current_branch? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    print_message "$GREEN" "✓ Git repository state is clean"
}

# Run quality gates
run_quality_gates() {
    print_message "$BLUE" "Running quality gates..."

    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        print_message "$YELLOW" "Warning: npm not found, skipping tests"
        return 0
    fi

    # Run lint if available
    if npm run lint &> /dev/null; then
        print_message "$GREEN" "✓ Lint passed"
    else
        print_message "$YELLOW" "⚠ Lint not available or failed"
    fi

    # Run tests if available
    if npm test &> /dev/null; then
        print_message "$GREEN" "✓ Tests passed"
    else
        print_message "$YELLOW" "⚠ Tests not available or failed"
    fi

    # Run build if available
    if npm run build &> /dev/null; then
        print_message "$GREEN" "✓ Build passed"
    else
        print_message "$YELLOW" "⚠ Build not available or failed"
    fi
}

# Bump version
bump_version() {
    local version="$1"
    local dry_run="$2"

    print_message "$BLUE" "Bumping version to $version..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would set version to $version"
    else
        "$SCRIPT_DIR/version-sync.sh" --set "$version"
        print_message "$GREEN" "✓ Version bumped to $version"
    fi
}

# Update changelog
update_changelog() {
    local version="$1"
    local from_git="$2"
    local dry_run="$3"

    print_message "$BLUE" "Updating changelog..."

    if [[ "$dry_run" == "true" ]]; then
        if [[ "$from_git" == "true" ]]; then
            print_message "$CYAN" "[DRY RUN] Would generate changelog from git commits"
        else
            print_message "$CYAN" "[DRY RUN] Would create new changelog entry"
        fi
    else
        if [[ "$from_git" == "true" ]]; then
            "$SCRIPT_DIR/changelog-generate.sh" --from-git "$version"
        else
            "$SCRIPT_DIR/changelog-generate.sh" --new "$version"
        fi
        print_message "$GREEN" "✓ Changelog updated"
    fi
}

# Commit release changes
commit_release() {
    local version="$1"
    local dry_run="$2"

    print_message "$BLUE" "Committing release changes..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would commit: release: v$version"
    else
        git add package.json .claude-plugin/plugin.json CHANGELOG.md marketplace-repo/plugins/bmad-ralph/CHANGELOG.md 2>/dev/null || true
        git commit -m "release: v$version

- Bump version to $version
- Update changelog
- Sync marketplace manifest"
        print_message "$GREEN" "✓ Release changes committed"
    fi
}

# Create git tag
create_tag() {
    local version="$1"
    local dry_run="$2"

    print_message "$BLUE" "Creating git tag v$version..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would create tag: v$version"
    else
        git tag -a "v$version" -m "Release v$version"
        print_message "$GREEN" "✓ Git tag v$version created"
    fi
}

# Update marketplace
update_marketplace() {
    local version="$1"
    local dry_run="$2"

    print_message "$BLUE" "Updating marketplace..."

    local marketplace_index="$PROJECT_ROOT/marketplace-repo/marketplace-index.json"

    if [[ ! -f "$marketplace_index" ]]; then
        print_message "$YELLOW" "Warning: Marketplace index not found"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would update marketplace index to version $version"
    else
        # Update version in marketplace index
        local temp_file
        temp_file=$(mktemp)
        jq --arg version "$version" '
            .plugins[] |= if .id == "bmad-ralph" then .version = $version else . end
        ' "$marketplace_index" > "$temp_file"
        mv "$temp_file" "$marketplace_index"

        # Update plugin manifest version
        local plugin_manifest="$PROJECT_ROOT/marketplace-repo/plugins/bmad-ralph/plugin.json"
        if [[ -f "$plugin_manifest" ]]; then
            temp_file=$(mktemp)
            jq --arg version "$version" '.version = $version' "$plugin_manifest" > "$temp_file"
            mv "$temp_file" "$plugin_manifest"
        fi

        git add marketplace-repo/ 2>/dev/null || true
        print_message "$GREEN" "✓ Marketplace updated"
    fi
}

# Push changes
push_release() {
    local dry_run="$1"

    print_message "$BLUE" "Pushing release..."

    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "[DRY RUN] Would push commits and tags to remote"
    else
        local current_branch
        current_branch=$(git branch --show-current)

        git push origin "$current_branch"
        git push origin --tags
        print_message "$GREEN" "✓ Release pushed to remote"
    fi
}

# Display release summary
display_summary() {
    local version="$1"
    local dry_run="$2"

    echo
    print_message "$CYAN" "═══════════════════════════════════════"
    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "  DRY RUN RELEASE SUMMARY"
    else
        print_message "$GREEN" "  RELEASE COMPLETE!"
    fi
    print_message "$CYAN" "═══════════════════════════════════════"
    echo
    print_message "$BLUE" "Version: $version"
    print_message "$BLUE" "Tag: v$version"
    echo

    if [[ "$dry_run" == "false" ]]; then
        print_message "$GREEN" "Next steps:"
        echo "  1. Review the release on GitHub"
        echo "  2. Create a GitHub Release from tag v$version"
        echo "  3. Announce the release to users"
        echo
        print_message "$YELLOW" "GitHub Release URL:"
        echo "  https://github.com/snarktank/ralph/releases/new?tag=v$version"
    else
        print_message "$YELLOW" "This was a dry run. No changes were made."
        print_message "$YELLOW" "Run without --dry-run to execute the release."
    fi
    echo
}

# Main script logic
main() {
    local version=""
    local dry_run="false"
    local from_git="false"
    local skip_tests="false"
    local skip_marketplace="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --from-git)
                from_git="true"
                shift
                ;;
            --skip-tests)
                skip_tests="true"
                shift
                ;;
            --skip-marketplace)
                skip_marketplace="true"
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

    # Validate version argument
    if [[ -z "$version" ]]; then
        print_message "$RED" "Error: VERSION argument is required"
        usage
    fi

    # Validate semver format
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        print_message "$RED" "Error: Invalid semver format: $version"
        exit 1
    fi

    # Check dependencies
    if ! command -v jq &> /dev/null; then
        print_message "$RED" "Error: jq is required but not installed"
        exit 1
    fi

    # Start release process
    print_message "$CYAN" "╔═══════════════════════════════════════╗"
    if [[ "$dry_run" == "true" ]]; then
        print_message "$CYAN" "║  BMAD Ralph Plugin Release (DRY RUN) ║"
    else
        print_message "$CYAN" "║   BMAD Ralph Plugin Release          ║"
    fi
    print_message "$CYAN" "╚═══════════════════════════════════════╝"
    echo

    # Step 1: Validate git state
    if [[ "$dry_run" == "false" ]]; then
        validate_git_state
    fi

    # Step 2: Run tests
    if [[ "$skip_tests" == "false" ]] && [[ "$dry_run" == "false" ]]; then
        run_quality_gates
    fi

    # Step 3: Bump version
    bump_version "$version" "$dry_run"

    # Step 4: Update changelog
    update_changelog "$version" "$from_git" "$dry_run"

    # Step 5: Commit changes
    commit_release "$version" "$dry_run"

    # Step 6: Create tag
    create_tag "$version" "$dry_run"

    # Step 7: Update marketplace
    if [[ "$skip_marketplace" == "false" ]]; then
        update_marketplace "$version" "$dry_run"
    fi

    # Step 8: Push to remote
    if [[ "$dry_run" == "false" ]]; then
        read -p "Push release to remote? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            push_release "$dry_run"
        else
            print_message "$YELLOW" "Skipped pushing to remote. You can push manually:"
            echo "  git push origin $(git branch --show-current)"
            echo "  git push origin --tags"
        fi
    fi

    # Display summary
    display_summary "$version" "$dry_run"
}

main "$@"
