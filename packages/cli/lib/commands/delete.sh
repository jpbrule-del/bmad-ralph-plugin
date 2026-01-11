#!/usr/bin/env bash
# ralph delete - Delete a loop

cmd_delete() {
  local loop_name=""
  local force=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph delete <loop-name> [--force]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph delete <loop-name> [--force]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph delete <loop-name> [--force]"
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
    if [[ -d "$archive_dir/$loop_name" ]] || [[ -d "$archive_dir"/*-"$loop_name" ]]; then
      error "Cannot delete archived loops"
      echo "Loop '$loop_name' is archived"
      echo "Archived loops are read-only for historical record"
      exit 1
    fi

    error "Loop '$loop_name' does not exist"
    echo "Run 'ralph list' to see available loops"
    exit 1
  fi

  # Get loop information for confirmation
  local prd_file="$loop_path/prd.json"
  local branch_name=""
  if [[ -f "$prd_file" ]]; then
    branch_name=$(jq -r '.branchName // ""' "$prd_file")
  fi

  # Prompt for confirmation if not force
  if [[ "$force" != "true" ]]; then
    echo ""
    warn "This will permanently delete the loop '$loop_name' and all its files"
    echo ""
    if [[ -n "$branch_name" ]]; then
      echo "Note: Git branch '$branch_name' will NOT be deleted"
      echo "      You can delete it manually with: git branch -d $branch_name"
      echo ""
    fi
    read -rp "Are you sure you want to delete this loop? [y/N]: " -n 1 confirm
    echo ""

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      info "Deletion cancelled"
      exit 0
    fi
  fi

  # Delete the loop directory
  if rm -rf "$loop_path"; then
    success "Loop '$loop_name' deleted successfully"

    # Warn about git branch
    if [[ -n "$branch_name" ]]; then
      echo ""
      info "Git branch '$branch_name' was not deleted"
      echo "To delete the branch, run:"
      echo "  git branch -d $branch_name"
    fi
  else
    error "Failed to delete loop '$loop_name'"
    exit 1
  fi
}
