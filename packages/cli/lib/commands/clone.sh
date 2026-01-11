#!/usr/bin/env bash
# ralph clone - Clone a loop

# Source git utilities
readonly CLONE_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
source "$CLONE_LIB_DIR/core/git.sh"

cmd_clone() {
  local source_name=""
  local dest_name=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph clone <source-loop> <destination-loop>"
        exit 1
        ;;
      *)
        if [[ -z "$source_name" ]]; then
          source_name="$1"
        elif [[ -z "$dest_name" ]]; then
          dest_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph clone <source-loop> <destination-loop>"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate arguments
  if [[ -z "$source_name" ]]; then
    error "Source loop name is required"
    echo "Usage: ralph clone <source-loop> <destination-loop>"
    exit 1
  fi

  if [[ -z "$dest_name" ]]; then
    error "Destination loop name is required"
    echo "Usage: ralph clone <source-loop> <destination-loop>"
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
  local source_path="$loops_dir/$source_name"
  local dest_path="$loops_dir/$dest_name"

  # Check if source loop exists in active loops
  if [[ ! -d "$source_path" ]]; then
    # Check if it's in archive
    local archive_match
    archive_match=$(find "$archive_dir" -maxdepth 1 -type d -name "*-$source_name" 2>/dev/null | head -n 1)

    if [[ -n "$archive_match" ]]; then
      source_path="$archive_match"
      info "Found source loop in archive: $(basename "$archive_match")"
    else
      error "Source loop '$source_name' does not exist"
      echo "Run 'ralph list' to see available loops"
      exit 1
    fi
  fi

  # Check if destination loop already exists
  if [[ -d "$dest_path" ]]; then
    error "Destination loop '$dest_name' already exists"
    echo "Choose a different destination name or delete the existing loop first"
    exit 1
  fi

  # Validate destination loop name (alphanumeric + hyphens)
  if ! [[ "$dest_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]] && ! [[ "$dest_name" =~ ^[a-zA-Z0-9]$ ]]; then
    error "Invalid destination loop name: $dest_name"
    echo ""
    echo "Loop name must:"
    echo "  • Contain only alphanumeric characters and hyphens"
    echo "  • Start with a letter or number"
    echo "  • Not end with a hyphen"
    echo ""
    echo "Valid examples: feature-auth, sprint-1, epic002"
    exit 1
  fi

  # Create destination directory
  info "Cloning loop '$source_name' to '$dest_name'..."
  mkdir -p "$dest_path"

  # Copy all files from source to destination
  if ! cp -r "$source_path"/* "$dest_path/"; then
    error "Failed to copy loop files"
    rm -rf "$dest_path"
    exit 1
  fi

  # Update prd.json with new loop name and reset stats
  local prd_file="$dest_path/prd.json"
  if [[ -f "$prd_file" ]]; then
    local temp_file
    temp_file=$(mktemp)

    # Update loopName, reset stats, generate new timestamp, and clear storyNotes
    local new_timestamp
    new_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg loop_name "$dest_name" \
       --arg timestamp "$new_timestamp" \
       '.loopName = $loop_name |
        .generatedAt = $timestamp |
        .stats.iterationsRun = 0 |
        .stats.storiesCompleted = 0 |
        .stats.startedAt = null |
        .stats.completedAt = null |
        .storyAttempts = {} |
        .storyNotes = {}' \
       "$prd_file" > "$temp_file"

    # Validate the updated JSON
    if ! jq . "$temp_file" >/dev/null 2>&1; then
      rm -f "$temp_file"
      error "Failed to update prd.json"
      rm -rf "$dest_path"
      exit 1
    fi

    # Move to final location (atomic write)
    mv "$temp_file" "$prd_file"
  else
    warn "prd.json not found in source loop"
  fi

  # Reset progress.txt with new header
  local progress_file="$dest_path/progress.txt"
  if [[ -f "$progress_file" ]]; then
    local project_name branch_name

    # Get project and branch info from prd.json
    if [[ -f "$prd_file" ]]; then
      project_name=$(jq -r '.project // "project"' "$prd_file")
      branch_name=$(jq -r '.branchName // "main"' "$prd_file")
    else
      project_name="project"
      branch_name="main"
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$progress_file" <<EOF
# Ralph Progress Log
# Loop: $dest_name
# Project: $project_name
# Branch: $branch_name
# Cloned from: $source_name
# Created: $timestamp

---

## Codebase Patterns
<!-- Add discovered patterns here as you implement stories -->

---

## Iteration Log
<!-- Each iteration appends here -->

EOF
  fi

  success "Loop cloned successfully: $source_name → $dest_name"
  echo ""
  echo "Next steps:"
  echo "  1. Create git branch: ralph create uses git automatically"
  echo "  2. Review configuration: ralph show $dest_name"
  echo "  3. Start execution: ralph run $dest_name"
  echo ""

  # Ask about creating git branch
  local branch_name="ralph/$dest_name"
  if branch_exists "$branch_name"; then
    local current_branch
    current_branch=$(get_current_branch)

    if [[ "$current_branch" == "$branch_name" ]]; then
      info "Already on branch: $branch_name"
    else
      warn "Branch already exists: $branch_name"
      echo ""
      read -p "Check out the existing branch? (y/N) " -n 1 -r
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        if git checkout "$branch_name" 2>/dev/null; then
          success "Checked out existing branch: $branch_name"
          # Update branchName in prd.json
          if [[ -f "$prd_file" ]]; then
            temp_file=$(mktemp)
            jq --arg branch "$branch_name" '.branchName = $branch' "$prd_file" > "$temp_file"
            mv "$temp_file" "$prd_file"
          fi
        else
          error "Failed to checkout branch: $branch_name"
        fi
      fi
    fi
  else
    echo "Create a new git branch for this loop?"
    read -p "Create branch '$branch_name'? (Y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      if create_loop_branch "$dest_name"; then
        # Update branchName in prd.json
        if [[ -f "$prd_file" ]]; then
          temp_file=$(mktemp)
          jq --arg branch "$branch_name" '.branchName = $branch' "$prd_file" > "$temp_file"
          mv "$temp_file" "$prd_file"
        fi
      fi
    fi
  fi
}
