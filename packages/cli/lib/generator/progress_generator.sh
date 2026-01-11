#!/usr/bin/env bash
# progress_generator.sh - Generate progress.txt iteration log file

# Get LIB_DIR from main script or fallback to relative path
readonly PROGRESS_GEN_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

# Generate progress.txt for a given loop
# Arguments:
#   $1: loop_name - Name of the loop
#   $2: loop_dir - Full path to loop directory
generate_progress_txt() {
  local loop_name="$1"
  local loop_dir="$2"

  local output_file="$loop_dir/progress.txt"

  # Get project info
  local project_name
  local sprint_status_path="docs/sprint-status.yaml"

  # Try to read project name from sprint-status.yaml
  if [[ -f "$sprint_status_path" ]]; then
    project_name=$(yq -r '.project_name // "project"' "$sprint_status_path" 2>/dev/null || echo "project")
  else
    # Fallback to git repo name or current directory name
    if git rev-parse --git-dir >/dev/null 2>&1; then
      project_name=$(basename "$(git rev-parse --show-toplevel)")
    else
      project_name=$(basename "$(pwd)")
    fi
  fi

  # Get current branch
  local branch_name
  if git rev-parse --git-dir >/dev/null 2>&1; then
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  else
    branch_name="main"
  fi

  # Generate timestamp
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Generate progress.txt content with header
  local progress_content
  read -r -d '' progress_content <<EOF || true
# Ralph Progress Log
# Loop: $loop_name
# Project: $project_name
# Branch: $branch_name
# Created: $timestamp

---

## Codebase Patterns
<!-- Add discovered patterns here as you implement stories -->

---

## Iteration Log
<!-- Each iteration appends here -->

EOF

  # Write to temp file first (atomic write pattern)
  local temp_file
  temp_file=$(mktemp)
  echo "$progress_content" > "$temp_file"

  # Move to final location
  mv "$temp_file" "$output_file"

  return 0
}
