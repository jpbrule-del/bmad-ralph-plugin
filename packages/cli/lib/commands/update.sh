#!/usr/bin/env bash
# update.sh - Update ralph CLI from git remote
#
# Usage: ralph update [--check] [--force] [--skip-skills]
#
# Pulls latest version from git remote and reinstalls CLI and skills.

readonly UPDATE_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
source "$UPDATE_LIB_DIR/core/output.sh"

# Get the ralph installation directory by resolving symlinks
get_ralph_install_dir() {
  local source="${BASH_SOURCE[0]}"

  # Resolve symlinks
  while [ -L "$source" ]; do
    local dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source"
  done

  # Go from lib/commands/ to repo root (up 4 levels: commands -> lib -> cli -> packages -> root)
  cd -P "$(dirname "$source")/../../../../" && pwd
}

# Get current local version
get_local_version() {
  local ralph_dir="$1"
  local package_json="$ralph_dir/packages/cli/package.json"

  if [[ -f "$package_json" ]]; then
    jq -r '.version // "unknown"' "$package_json" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

# Get remote version (requires fetch first)
get_remote_version() {
  local ralph_dir="$1"
  local remote_branch="${2:-origin/main}"

  # Try to get version from remote
  local version
  version=$(git -C "$ralph_dir" show "$remote_branch:packages/cli/package.json" 2>/dev/null | jq -r '.version // "unknown"' 2>/dev/null)

  if [[ -z "$version" ]] || [[ "$version" == "null" ]]; then
    # Try origin/master if main doesn't exist
    version=$(git -C "$ralph_dir" show "origin/master:packages/cli/package.json" 2>/dev/null | jq -r '.version // "unknown"' 2>/dev/null)
  fi

  echo "${version:-unknown}"
}

# Check if working directory has uncommitted changes
is_dirty() {
  local ralph_dir="$1"
  ! git -C "$ralph_dir" diff-index --quiet HEAD -- 2>/dev/null
}

# Install skills to Claude Code commands directory
install_skills() {
  local ralph_dir="$1"
  local skills_src="$ralph_dir/packages/cli/skills/ralph"
  local skills_dest="$HOME/.claude/commands/ralph"

  if [[ ! -d "$skills_src" ]]; then
    warning "Skills source not found: $skills_src"
    return 1
  fi

  mkdir -p "$skills_dest"
  cp "$skills_src"/*.md "$skills_dest/" 2>/dev/null || {
    warning "No skill files found to copy"
    return 1
  }

  local count
  count=$(ls -1 "$skills_dest"/*.md 2>/dev/null | wc -l | tr -d ' ')
  success "Installed $count skill files to $skills_dest"
  return 0
}

# Main update command
cmd_update() {
  local check_only=false
  local force=false
  local skip_skills=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check|-c)
        check_only=true
        shift
        ;;
      --force|-f)
        force=true
        shift
        ;;
      --skip-skills)
        skip_skills=true
        shift
        ;;
      --help|-h)
        echo "Usage: ralph update [--check] [--force] [--skip-skills]"
        echo ""
        echo "Update ralph CLI from git remote."
        echo ""
        echo "Options:"
        echo "  --check, -c      Check for updates without installing"
        echo "  --force, -f      Update even with uncommitted local changes"
        echo "  --skip-skills    Skip reinstalling Claude Code skills"
        echo ""
        exit 0
        ;;
      -*)
        error "Unknown option: $1"
        echo "Run 'ralph update --help' for usage"
        exit 1
        ;;
      *)
        error "Unexpected argument: $1"
        exit 1
        ;;
    esac
  done

  # Find ralph installation directory
  local ralph_dir
  ralph_dir=$(get_ralph_install_dir)

  if [[ ! -d "$ralph_dir/.git" ]]; then
    error "Ralph installation directory is not a git repository: $ralph_dir"
    echo ""
    echo "The update command requires ralph to be installed from git."
    echo "If you installed via npm, update with: npm update -g @ralph/cli"
    exit 1
  fi

  info "Ralph installation: $ralph_dir"

  # Check for uncommitted changes
  if is_dirty "$ralph_dir"; then
    if [[ "$force" == false ]] && [[ "$check_only" == false ]]; then
      error "Ralph installation has uncommitted local changes"
      echo ""
      echo "Options:"
      echo "  1. Commit or stash your changes first"
      echo "  2. Use --force to update anyway (may lose local changes)"
      echo ""
      exit 1
    elif [[ "$force" == true ]]; then
      warning "Proceeding with uncommitted changes (--force)"
    fi
  fi

  # Get current version
  local current_version
  current_version=$(get_local_version "$ralph_dir")
  info "Current version: $current_version"

  # Fetch latest from remote
  info "Fetching latest from remote..."
  if ! git -C "$ralph_dir" fetch origin 2>/dev/null; then
    error "Failed to fetch from remote"
    echo ""
    echo "Check your network connection and git remote configuration."
    exit 1
  fi

  # Determine remote branch
  local remote_branch="origin/main"
  if ! git -C "$ralph_dir" rev-parse --verify "$remote_branch" >/dev/null 2>&1; then
    remote_branch="origin/master"
  fi

  # Get remote version
  local remote_version
  remote_version=$(get_remote_version "$ralph_dir" "$remote_branch")

  # Compare versions
  local current_branch
  current_branch=$(git -C "$ralph_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

  local local_commit
  local_commit=$(git -C "$ralph_dir" rev-parse HEAD 2>/dev/null | cut -c1-7)

  local remote_commit
  remote_commit=$(git -C "$ralph_dir" rev-parse "$remote_branch" 2>/dev/null | cut -c1-7)

  # Check if update is available
  local updates_available=false
  if [[ "$local_commit" != "$remote_commit" ]]; then
    updates_available=true
  fi

  if [[ "$check_only" == true ]]; then
    echo ""
    header "Update Status"
    echo "  Current version: $current_version ($local_commit)"
    echo "  Remote version:  $remote_version ($remote_commit)"
    echo "  Branch:          $current_branch → $remote_branch"
    echo ""

    if [[ "$updates_available" == true ]]; then
      echo -e "  ${COLOR_YELLOW}Updates available!${COLOR_RESET}"
      echo ""
      echo "  Run 'ralph update' to install the latest version."

      # Show commit log
      echo ""
      echo "  Recent changes:"
      git -C "$ralph_dir" log --oneline HEAD.."$remote_branch" 2>/dev/null | head -10 | while read -r line; do
        echo "    $line"
      done
    else
      echo -e "  ${COLOR_GREEN}Already up to date.${COLOR_RESET}"
    fi
    echo ""
    exit 0
  fi

  # Perform update
  if [[ "$updates_available" == false ]]; then
    success "Already up to date ($current_version)"
    exit 0
  fi

  echo ""
  header "Updating Ralph"
  echo "  $current_version ($local_commit) → $remote_version ($remote_commit)"
  echo ""

  # Pull latest changes
  info "Pulling latest changes..."
  if [[ "$force" == true ]]; then
    # Force pull - reset to remote
    if ! git -C "$ralph_dir" reset --hard "$remote_branch" 2>/dev/null; then
      error "Failed to reset to remote branch"
      exit 1
    fi
  else
    # Normal pull
    if ! git -C "$ralph_dir" pull origin "$current_branch" 2>/dev/null; then
      error "Failed to pull changes"
      echo ""
      echo "There may be merge conflicts. Resolve them manually or use --force."
      exit 1
    fi
  fi
  success "Pulled latest changes"

  # Install npm dependencies
  info "Installing npm dependencies..."
  local cli_dir="$ralph_dir/packages/cli"
  if ! npm install --silent --prefix "$cli_dir" 2>/dev/null; then
    warning "npm install had issues (continuing anyway)"
  else
    success "Installed npm dependencies"
  fi

  # Re-link CLI globally
  info "Linking CLI globally..."
  cd "$cli_dir"
  if npm link 2>/dev/null; then
    success "Linked CLI globally"
  else
    warning "npm link failed (may need sudo)"
    echo "  Try: cd $cli_dir && sudo npm link"
  fi
  cd - >/dev/null

  # Install skills
  if [[ "$skip_skills" == false ]]; then
    info "Installing Claude Code skills..."
    install_skills "$ralph_dir"
  else
    info "Skipping skills installation (--skip-skills)"
  fi

  # Verify update
  local new_version
  new_version=$(get_local_version "$ralph_dir")

  echo ""
  echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
  echo -e "${COLOR_GREEN}   Update Complete!${COLOR_RESET}"
  echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
  echo ""
  echo "  Version: $current_version → $new_version"
  echo ""
  echo "  Verify with: ralph --version"
  echo ""
}
