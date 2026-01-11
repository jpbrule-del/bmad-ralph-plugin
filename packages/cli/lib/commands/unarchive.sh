#!/usr/bin/env bash
# ralph unarchive - Restore a loop from archive

cmd_unarchive() {
  local loop_name=""
  local reset_stats=false
  local no_branch=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reset-stats)
        reset_stats=true
        shift
        ;;
      --no-branch)
        no_branch=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph unarchive <loop-name> [--reset-stats] [--no-branch]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph unarchive <loop-name> [--reset-stats] [--no-branch]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph unarchive <loop-name> [--reset-stats] [--no-branch]"
    exit 1
  fi

  # Ensure ralph is initialized
  if [[ ! -d "ralph" ]]; then
    error "Ralph is not initialized in this project"
    echo "Run 'ralph init' to initialize"
    exit 1
  fi

  local loops_dir="ralph/loops"
  local archive_dir="ralph/archive"
  local archive_path=""

  # Find the archived loop (with or without date prefix)
  if [[ -d "$archive_dir/$loop_name" ]]; then
    archive_path="$archive_dir/$loop_name"
  elif compgen -G "$archive_dir/*-$loop_name" > /dev/null 2>&1; then
    # Find date-prefixed archive directory
    archive_path=$(find "$archive_dir" -maxdepth 1 -type d -name "*-$loop_name" | head -n 1)
  fi

  # Check if archived loop exists
  if [[ -z "$archive_path" ]] || [[ ! -d "$archive_path" ]]; then
    error "Archived loop '$loop_name' not found"
    echo "Run 'ralph list --archived' to see archived loops"
    exit 1
  fi

  # Check if loop already exists in active loops
  local destination_path="$loops_dir/$loop_name"
  if [[ -d "$destination_path" ]]; then
    error "Loop '$loop_name' already exists in active loops"
    echo "Delete the active loop first, or choose a different name"
    exit 1
  fi

  local prd_file="$archive_path/config.json"

  # Validate config.json exists
  if [[ ! -f "$prd_file" ]]; then
    error "Loop configuration file not found: $prd_file"
    exit 1
  fi

  # Create loops directory if it doesn't exist
  mkdir -p "$loops_dir"

  # Move loop back to active
  if mv "$archive_path" "$destination_path"; then
    success "Loop '$loop_name' restored to active loops"
    echo ""
    info "Loop location: $destination_path"

    # Remove archivedAt timestamp from config.json
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    # shellcheck source=../core/utils.sh
    source "$lib_dir/core/utils.sh"

    local restored_prd
    restored_prd=$(jq 'del(.archivedAt)' "$destination_path/config.json")

    # Reset stats if --reset-stats flag provided
    if [[ "$reset_stats" == "true" ]]; then
      info "Resetting execution statistics..."
      restored_prd=$(echo "$restored_prd" | jq '
        .stats.iterationsRun = 0 |
        .stats.storiesCompleted = 0 |
        .stats.startedAt = null |
        .stats.completedAt = null |
        .stats.averageIterationsPerStory = 0 |
        .storyAttempts = {} |
        .storyNotes = {}
      ')
    fi

    # Save updated config.json
    if atomic_write_json "$destination_path/config.json" "$restored_prd"; then
      if [[ "$reset_stats" == "true" ]]; then
        success "Execution statistics reset"
      fi
    else
      warning "Failed to update config.json"
    fi

    # Feedback.json is preserved in the loop directory
    if [[ -f "$destination_path/feedback.json" ]]; then
      info "Previous feedback preserved in: $destination_path/feedback.json"
    fi

    echo ""

    # Create git branch if needed
    if [[ "$no_branch" != "true" ]]; then
      # shellcheck source=../core/git.sh
      source "$lib_dir/core/git.sh"

      # Check if we're in a git repo
      if git rev-parse --git-dir > /dev/null 2>&1; then
        # Extract branch name from config.json
        local branch_name
        branch_name=$(echo "$restored_prd" | jq -r '.branchName // empty')

        if [[ -z "$branch_name" ]]; then
          # Generate branch name if not in config.json
          branch_name="ralph/$loop_name"
        fi

        # Check if branch already exists
        if git_branch_exists "$branch_name"; then
          info "Git branch '$branch_name' already exists"
          echo -n "Do you want to checkout this existing branch? [Y/n] "
          read -r -n 1 response
          echo ""

          if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
            if git checkout "$branch_name" 2>/dev/null; then
              success "Checked out branch: $branch_name"
            else
              warning "Failed to checkout branch '$branch_name'"
              echo "You may need to commit or stash changes first"
            fi
          fi
        else
          # Prompt to create new branch
          echo -n "Create and checkout new branch '$branch_name'? [Y/n] "
          read -r -n 1 response
          echo ""

          if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
            if git_create_and_checkout_branch "$branch_name"; then
              success "Created and checked out branch: $branch_name"
            else
              warning "Failed to create branch '$branch_name'"
            fi
          fi
        fi
      else
        warning "Not in a git repository - skipping branch creation"
      fi
    else
      info "Skipping git branch creation (--no-branch flag provided)"
    fi

    echo ""
    echo "The loop is now active and can be run or edited."
    echo ""
    echo "Next steps:"
    echo "  ralph show $loop_name      # View loop details"
    echo "  ralph run $loop_name       # Run the loop"
    echo "  ralph edit $loop_name      # Edit configuration"
  else
    error "Failed to restore loop '$loop_name'"
    echo "The loop was not moved from archive"
    exit 1
  fi
}
