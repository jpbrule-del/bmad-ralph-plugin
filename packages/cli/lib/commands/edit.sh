#!/usr/bin/env bash
# ralph edit - Edit loop configuration

cmd_edit() {
  local loop_name=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph edit <loop-name>"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph edit <loop-name>"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph edit <loop-name>"
    exit 1
  fi

  # Ensure ralph is initialized
  if [[ ! -d "ralph" ]]; then
    error "Ralph is not initialized in this project"
    echo "Run 'ralph init' to initialize"
    exit 1
  fi

  # Check for EDITOR environment variable
  if [[ -z "${EDITOR:-}" ]]; then
    error "EDITOR environment variable is not set"
    echo "Set your preferred editor: export EDITOR=vim"
    exit 1
  fi

  local loops_dir="ralph/loops"
  local archive_dir="ralph/archive"
  local loop_path=""
  local is_archived=false

  # Check if loop exists in active loops
  if [[ -d "$loops_dir/$loop_name" ]]; then
    loop_path="$loops_dir/$loop_name"
  # Check if it's in archive (with or without date prefix)
  elif [[ -d "$archive_dir/$loop_name" ]]; then
    loop_path="$archive_dir/$loop_name"
    is_archived=true
  else
    # Try to find with date prefix
    local archived_path=$(find "$archive_dir" -maxdepth 1 -type d -name "*-$loop_name" 2>/dev/null | head -1)
    if [[ -n "$archived_path" ]]; then
      loop_path="$archived_path"
      is_archived=true
    else
      error "Loop '$loop_name' does not exist"
      echo "Run 'ralph list' to see available loops"
      exit 1
    fi
  fi

  # Prevent editing archived loops
  if [[ "$is_archived" == "true" ]]; then
    error "Cannot edit archived loop '$loop_name'"
    echo "Archived loops are read-only"
    echo "Use 'ralph unarchive $loop_name' to restore it to active loops"
    exit 1
  fi

  local prd_file="$loop_path/config.json"
  if [[ ! -f "$prd_file" ]]; then
    error "Loop configuration file not found: $prd_file"
    exit 1
  fi

  # Create backup
  local backup_file="${prd_file}.backup"
  cp "$prd_file" "$backup_file"

  info "Opening $prd_file in $EDITOR"
  echo ""

  # Edit loop
  local edit_success=false
  while [[ "$edit_success" == "false" ]]; do
    # Open in editor
    $EDITOR "$prd_file"

    # Validate JSON
    if jq empty "$prd_file" 2>/dev/null; then
      success "Configuration validated successfully"
      edit_success=true
      # Remove backup
      rm -f "$backup_file"
    else
      error "Invalid JSON in configuration file"
      echo ""
      echo "The configuration file contains invalid JSON."
      echo ""
      echo "What would you like to do?"
      echo "  1) Edit again"
      echo "  2) Restore backup and cancel"
      echo ""
      read -p "Choice (1-2): " -n 1 -r choice
      echo ""

      case "$choice" in
        1)
          # Continue loop to edit again
          ;;
        2)
          # Restore backup
          mv "$backup_file" "$prd_file"
          warn "Changes discarded, original configuration restored"
          exit 0
          ;;
        *)
          error "Invalid choice"
          mv "$backup_file" "$prd_file"
          warn "Changes discarded, original configuration restored"
          exit 1
          ;;
      esac
    fi
  done

  echo ""
  info "Configuration updated for loop: $loop_name"
}
