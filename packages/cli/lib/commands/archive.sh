#!/usr/bin/env bash
# ralph archive - Archive a loop

cmd_archive() {
  local loop_name=""
  local skip_feedback=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-feedback)
        skip_feedback=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph archive <loop-name> [--skip-feedback]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph archive <loop-name> [--skip-feedback]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph archive <loop-name> [--skip-feedback]"
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
    # Check if already archived
    if [[ -d "$archive_dir/$loop_name" ]] || compgen -G "$archive_dir/*-$loop_name" > /dev/null 2>&1; then
      error "Loop '$loop_name' is already archived"
      echo "Run 'ralph list --archived' to see archived loops"
      exit 1
    fi

    error "Loop '$loop_name' does not exist"
    echo "Run 'ralph list' to see available loops"
    exit 1
  fi

  local prd_file="$loop_path/config.json"

  # Validate config.json exists
  if [[ ! -f "$prd_file" ]]; then
    error "Loop configuration file not found: $prd_file"
    exit 1
  fi

  # Check if loop is currently running
  local lock_file="$loop_path/.lock"
  if [[ -f "$lock_file" ]]; then
    local pid
    pid=$(cat "$lock_file" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      error "Cannot archive loop while it is running"
      echo "Loop '$loop_name' is currently executing (PID: $pid)"
      echo "Stop the loop or wait for it to complete before archiving"
      exit 1
    fi
  fi

  # Collect feedback (STORY-051: Implement mandatory feedback questionnaire)
  local feedback_json=""
  if [[ "$skip_feedback" != "true" ]]; then
    # Source feedback questionnaire module
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    # shellcheck source=../feedback/questionnaire.sh
    source "$lib_dir/feedback/questionnaire.sh"

    # Collect feedback from user
    feedback_json=$(collect_feedback "$loop_name" "$prd_file")

    # Check if feedback collection was successful
    if [[ $? -ne 0 ]] || [[ -z "$feedback_json" ]]; then
      error "Feedback collection failed or was cancelled"
      echo "Loop will not be archived without feedback."
      echo ""
      echo "To archive without feedback (not recommended), use:"
      echo "  ralph archive $loop_name --skip-feedback"
      exit 1
    fi
  else
    info "Skipping feedback collection (--skip-feedback flag provided)"
  fi

  # Create archive directory if it doesn't exist
  mkdir -p "$archive_dir"

  # Generate archive directory name with date prefix
  local archive_date
  archive_date=$(date +%Y-%m-%d)
  local archive_path="$archive_dir/${archive_date}-${loop_name}"

  # Check if archive destination already exists
  if [[ -d "$archive_path" ]]; then
    error "Archive destination already exists: $archive_path"
    echo "This may happen if you archived a loop with the same name today."
    exit 1
  fi

  # Record archive timestamp in config.json before moving
  local archive_timestamp
  archive_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local temp_prd
  temp_prd=$(mktemp)

  if ! jq --arg timestamp "$archive_timestamp" \
    '. + {archivedAt: $timestamp}' \
    "$prd_file" > "$temp_prd"; then
    rm -f "$temp_prd"
    error "Failed to update archive timestamp in config.json"
    exit 1
  fi

  # Atomic write
  if ! mv "$temp_prd" "$prd_file"; then
    rm -f "$temp_prd"
    error "Failed to save archive timestamp"
    exit 1
  fi

  # Move loop to archive
  if mv "$loop_path" "$archive_path"; then
    # STORY-052: Save feedback to archive directory with atomic write
    if [[ -n "$feedback_json" ]]; then
      local feedback_file="$archive_path/feedback.json"

      # Source utils module for atomic write functions
      # shellcheck source=../core/utils.sh
      source "$lib_dir/core/utils.sh"

      # Use atomic write for feedback storage
      if atomic_write_json "$feedback_file" "$feedback_json"; then
        info "Feedback saved to: $feedback_file"
      else
        warning "Failed to save feedback to archive"
        # Don't fail the archive operation if feedback save fails
        # The loop is already moved, so we just log a warning
      fi
    fi

    success "Loop '$loop_name' archived successfully"
    echo ""
    info "Archive location: $archive_path"
    info "Archived at: $archive_timestamp"
    echo ""
    echo "The loop is now read-only for historical record."
    echo "To view archived loops, run:"
    echo "  ralph list --archived"
    echo "  ralph show ${archive_date}-${loop_name}"
  else
    error "Failed to archive loop '$loop_name'"
    echo "The loop was not moved to archive"
    exit 1
  fi
}
