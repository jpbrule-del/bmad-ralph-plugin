#!/usr/bin/env bash
# uninstall.sh - Completely remove ralph from the system
#
# Usage: ralph uninstall [--force] [--keep-projects] [--dry-run]
#
# Removes all ralph components: CLI, skills, and optionally project data.

readonly UNINSTALL_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
source "$UNINSTALL_LIB_DIR/core/output.sh"

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

# Count files in a directory
count_files() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    find "$dir" -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

# Get directory size in human-readable format
get_dir_size() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    du -sh "$dir" 2>/dev/null | cut -f1
  else
    echo "0"
  fi
}

# Main uninstall command
cmd_uninstall() {
  local force=false
  local keep_projects=false
  local dry_run=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f)
        force=true
        shift
        ;;
      --keep-projects)
        keep_projects=true
        shift
        ;;
      --dry-run|-n)
        dry_run=true
        shift
        ;;
      --help|-h)
        echo "Usage: ralph uninstall [--force] [--keep-projects] [--dry-run]"
        echo ""
        echo "Completely remove ralph from the system."
        echo ""
        echo "This will remove:"
        echo "  - Global CLI (npm unlink)"
        echo "  - Claude Code skills (~/.claude/commands/ralph/)"
        echo "  - Project ralph/ directories (unless --keep-projects)"
        echo "  - ralph/* git branches in current project"
        echo ""
        echo "Options:"
        echo "  --force, -f       Skip confirmation prompts"
        echo "  --keep-projects   Don't remove project-level ralph/ directories"
        echo "  --dry-run, -n     Show what would be removed without removing"
        echo ""
        exit 0
        ;;
      -*)
        error "Unknown option: $1"
        echo "Run 'ralph uninstall --help' for usage"
        exit 1
        ;;
      *)
        error "Unexpected argument: $1"
        exit 1
        ;;
    esac
  done

  echo ""
  echo -e "${COLOR_RED}========================================${COLOR_RESET}"
  echo -e "${COLOR_RED}   Ralph Uninstall${COLOR_RESET}"
  echo -e "${COLOR_RED}========================================${COLOR_RESET}"
  echo ""

  if [[ "$dry_run" == true ]]; then
    echo -e "${COLOR_YELLOW}DRY RUN - No changes will be made${COLOR_RESET}"
    echo ""
  fi

  # Find ralph installation directory
  local ralph_dir
  ralph_dir=$(get_ralph_install_dir)

  # Collect what will be removed
  local items_to_remove=()
  local total_size=0

  # 1. Skills directory
  local skills_dir="$HOME/.claude/commands/ralph"
  if [[ -d "$skills_dir" ]]; then
    local skills_count
    skills_count=$(count_files "$skills_dir")
    local skills_size
    skills_size=$(get_dir_size "$skills_dir")
    items_to_remove+=("skills:$skills_dir:$skills_count files:$skills_size")
    echo "  [1] Claude Code skills"
    echo "      Path: $skills_dir"
    echo "      Files: $skills_count ($skills_size)"
    echo ""
  fi

  # 2. Global CLI
  local cli_location
  cli_location=$(which ralph 2>/dev/null || echo "")
  if [[ -n "$cli_location" ]]; then
    items_to_remove+=("cli:$cli_location")
    echo "  [2] Global CLI"
    echo "      Path: $cli_location"
    echo ""
  fi

  # 3. Current project ralph/ directory
  local project_ralph_dir=""
  if [[ "$keep_projects" == false ]]; then
    # Check if we're in a project with ralph/ directory
    if [[ -d "ralph" ]]; then
      project_ralph_dir="$(pwd)/ralph"
      local project_files
      project_files=$(count_files "$project_ralph_dir")
      local project_size
      project_size=$(get_dir_size "$project_ralph_dir")
      items_to_remove+=("project:$project_ralph_dir:$project_files files:$project_size")
      echo "  [3] Current project ralph/ directory"
      echo "      Path: $project_ralph_dir"
      echo "      Files: $project_files ($project_size)"
      echo ""
    fi
  else
    echo "  [3] Project directories: SKIPPED (--keep-projects)"
    echo ""
  fi

  # 4. Git branches
  local ralph_branches=()
  if git rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r branch; do
      if [[ -n "$branch" ]]; then
        ralph_branches+=("$branch")
      fi
    done < <(git branch --list 'ralph/*' 2>/dev/null | sed 's/^[* ]*//')

    if [[ ${#ralph_branches[@]} -gt 0 ]]; then
      items_to_remove+=("branches:${#ralph_branches[@]}")
      echo "  [4] Git branches (ralph/*)"
      for branch in "${ralph_branches[@]}"; do
        echo "      - $branch"
      done
      echo ""
    fi
  fi

  # 5. Ralph source directory (optional - only if installed from git)
  if [[ -d "$ralph_dir/.git" ]]; then
    local source_size
    source_size=$(get_dir_size "$ralph_dir")
    echo "  [5] Ralph source directory"
    echo "      Path: $ralph_dir"
    echo "      Size: $source_size"
    echo -e "      ${COLOR_YELLOW}NOTE: This directory will NOT be removed automatically.${COLOR_RESET}"
    echo "      Remove manually with: rm -rf $ralph_dir"
    echo ""
  fi

  if [[ ${#items_to_remove[@]} -eq 0 ]]; then
    echo "  Nothing to uninstall."
    echo ""
    exit 0
  fi

  # Confirmation
  if [[ "$dry_run" == true ]]; then
    echo -e "${COLOR_YELLOW}DRY RUN complete. No changes were made.${COLOR_RESET}"
    echo ""
    echo "To perform the uninstall, run: ralph uninstall"
    echo ""
    exit 0
  fi

  if [[ "$force" == false ]]; then
    echo -e "${COLOR_RED}WARNING: This action is irreversible!${COLOR_RESET}"
    echo ""
    read -p "Are you sure you want to uninstall ralph? (type 'yes' to confirm): " confirm
    echo ""

    if [[ "$confirm" != "yes" ]]; then
      echo "Uninstall cancelled."
      exit 0
    fi
  fi

  # Perform uninstall
  header "Removing Ralph Components"
  echo ""

  local errors=0

  # Remove skills
  if [[ -d "$skills_dir" ]]; then
    info "Removing Claude Code skills..."
    if rm -rf "$skills_dir" 2>/dev/null; then
      success "Removed: $skills_dir"
    else
      error "Failed to remove: $skills_dir"
      ((errors++))
    fi
  fi

  # Unlink global CLI
  if [[ -n "$cli_location" ]]; then
    info "Unlinking global CLI..."
    local cli_dir="$ralph_dir/packages/cli"
    if [[ -d "$cli_dir" ]]; then
      cd "$cli_dir"
      if npm unlink 2>/dev/null; then
        success "Unlinked CLI from npm"
      else
        # Try alternative method
        if npm unlink -g @ralph/cli 2>/dev/null; then
          success "Unlinked CLI from npm (global)"
        else
          warning "npm unlink failed (CLI may already be removed)"
        fi
      fi
      cd - >/dev/null
    else
      warning "CLI directory not found, skipping unlink"
    fi
  fi

  # Remove project ralph/ directory
  if [[ -n "$project_ralph_dir" ]] && [[ -d "$project_ralph_dir" ]]; then
    info "Removing project ralph/ directory..."
    if rm -rf "$project_ralph_dir" 2>/dev/null; then
      success "Removed: $project_ralph_dir"
    else
      error "Failed to remove: $project_ralph_dir"
      ((errors++))
    fi
  fi

  # Delete git branches
  if [[ ${#ralph_branches[@]} -gt 0 ]]; then
    info "Deleting ralph/* git branches..."
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Switch to main/master if on a ralph branch
    if [[ "$current_branch" == ralph/* ]]; then
      if git checkout main 2>/dev/null || git checkout master 2>/dev/null; then
        success "Switched to main branch"
      else
        warning "Could not switch from ralph branch"
      fi
    fi

    for branch in "${ralph_branches[@]}"; do
      if git branch -D "$branch" 2>/dev/null; then
        success "Deleted branch: $branch"
      else
        warning "Could not delete branch: $branch"
      fi
    done
  fi

  # Summary
  echo ""
  if [[ $errors -eq 0 ]]; then
    echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}   Uninstall Complete!${COLOR_RESET}"
    echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
    echo ""
    echo "  Ralph has been removed from your system."
    echo ""
    if [[ -d "$ralph_dir/.git" ]]; then
      echo "  To completely remove ralph, also delete the source:"
      echo "    rm -rf $ralph_dir"
      echo ""
    fi
    echo "  To reinstall later:"
    echo "    git clone https://github.com/snarktank/ralph.git"
    echo "    cd ralph && ./install.sh"
    echo ""
  else
    echo -e "${COLOR_YELLOW}========================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   Uninstall completed with warnings${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}========================================${COLOR_RESET}"
    echo ""
    echo "  Some components could not be removed. See errors above."
    echo ""
  fi
}
