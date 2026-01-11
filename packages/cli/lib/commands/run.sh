#!/usr/bin/env bash
# ralph run - Run a loop

# Source required modules
source "$LIB_DIR/core/git.sh"

cmd_run() {
  local loop_name=""
  local dry_run=false
  local restart=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      --restart)
        restart=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph run <loop-name> [--dry-run] [--restart]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph run <loop-name> [--dry-run] [--restart]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph run <loop-name> [--dry-run] [--restart]"
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
  local loop_path="$loops_dir/$loop_name"

  # Check if loop exists in active loops
  if [[ ! -d "$loop_path" ]]; then
    # Check if it's in archive
    if [[ -d "$archive_dir/$loop_name" ]] || compgen -G "$archive_dir/*-$loop_name" >/dev/null 2>&1; then
      error "Cannot run archived loops"
      echo "Loop '$loop_name' is archived"
      echo "Use 'ralph unarchive $loop_name' first to restore it"
      exit 1
    fi

    error "Loop '$loop_name' does not exist"
    echo "Run 'ralph list' to see available loops"
    exit 1
  fi

  # Validate prd.json exists
  local prd_file="$loop_path/prd.json"
  if [[ ! -f "$prd_file" ]]; then
    error "Invalid loop: prd.json not found"
    exit 1
  fi

  # Get branch name from prd.json
  local branch_name
  branch_name=$(jq -r '.branchName // ""' "$prd_file")
  if [[ -z "$branch_name" ]]; then
    error "Invalid loop: branchName not found in prd.json"
    exit 1
  fi

  # Check for existing lock file
  local lock_file="$loop_path/.lock"
  if [[ -f "$lock_file" ]]; then
    local lock_pid
    lock_pid=$(cat "$lock_file" 2>/dev/null)

    # Check if the process is still running
    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
      error "Loop is already running (PID: $lock_pid)"
      echo "If you believe this is an error, remove the lock file:"
      echo "  rm \"$lock_file\""
      exit 1
    else
      # Stale lock file - remove it
      warning "Removing stale lock file"
      rm -f "$lock_file"
    fi
  fi

  # Create lock file with current PID
  echo $$ > "$lock_file"

  # Set up trap to remove lock file on exit
  trap "rm -f '$lock_file'" EXIT INT TERM

  # Checkout the associated git branch
  local current_branch
  current_branch=$(get_current_branch)

  if [[ "$current_branch" != "$branch_name" ]]; then
    info "Checking out branch: $branch_name"

    # Check if branch exists
    if ! branch_exists "$branch_name"; then
      error "Branch does not exist: $branch_name"
      echo "The loop configuration references a branch that doesn't exist."
      echo "You may need to create it manually or update prd.json"
      exit 1
    fi

    # Checkout the branch
    if ! git checkout "$branch_name" 2>/dev/null; then
      error "Failed to checkout branch: $branch_name"
      echo "Ensure there are no uncommitted changes or conflicts"
      exit 1
    fi

    success "Checked out branch: $branch_name"
  else
    info "Already on branch: $branch_name"
  fi

  # Placeholder for future implementation
  # STORY-031 will implement the actual Claude CLI integration
  # STORY-039 will implement --dry-run functionality
  # The loop.sh script in each loop directory will handle the actual execution

  success "Loop validation passed"
  info "Loop '$loop_name' is ready to run"
  echo ""
  echo "The actual execution logic (Claude CLI integration) will be implemented in STORY-031"
  echo ""
  echo "For now, you can run the loop script directly:"
  echo "  cd $loop_path && bash loop.sh"
}
