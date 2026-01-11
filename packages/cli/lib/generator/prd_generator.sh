#!/usr/bin/env bash
# prd_generator.sh - Generate prd.json loop configuration file

# Get LIB_DIR from main script or fallback to relative path
readonly PRD_GEN_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

# Source bmad_config utilities
# shellcheck source=lib/core/bmad_config.sh
source "$PRD_GEN_LIB_DIR/core/bmad_config.sh"

# Generate prd.json for a given loop
# Arguments:
#   $1: loop_name - Name of the loop
#   $2: loop_dir - Full path to loop directory
#   $3: epic_filter - Optional epic filter (or empty string for "all")
#   $4: max_iterations - Max iterations (default: 50)
#   $5: stuck_threshold - Stuck threshold (default: 3)
generate_prd_json() {
  local loop_name="$1"
  local loop_dir="$2"
  local epic_filter="${3:-}"
  local max_iterations="${4:-50}"
  local stuck_threshold="${5:-3}"

  local output_file="$loop_dir/prd.json"

  # Get project info from BMAD config
  local project_name
  local sprint_status_path

  # Use BMAD config detection for project name and sprint status path
  project_name=$(get_bmad_project_name)
  sprint_status_path=$(get_bmad_sprint_status_path || echo "docs/sprint-status.yaml")

  # Get current branch
  local branch_name
  if git rev-parse --git-dir >/dev/null 2>&1; then
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  else
    branch_name="main"
  fi

  # Read quality gate commands from ralph/config.yaml or ralph/config.json
  local typecheck_cmd="null"
  local test_cmd="null"
  local lint_cmd="null"
  local build_cmd="null"

  if [[ -f "ralph/config.yaml" ]]; then
    local tmp_typecheck tmp_test tmp_lint tmp_build
    tmp_typecheck=$(yq -r '.qualityGates.typecheck // ""' ralph/config.yaml 2>/dev/null || echo "")
    tmp_test=$(yq -r '.qualityGates.test // ""' ralph/config.yaml 2>/dev/null || echo "")
    tmp_lint=$(yq -r '.qualityGates.lint // ""' ralph/config.yaml 2>/dev/null || echo "")
    tmp_build=$(yq -r '.qualityGates.build // ""' ralph/config.yaml 2>/dev/null || echo "")

    # Convert empty strings to null for JSON
    [[ -n "$tmp_typecheck" ]] && typecheck_cmd="\"$tmp_typecheck\""
    [[ -n "$tmp_test" ]] && test_cmd="\"$tmp_test\""
    [[ -n "$tmp_lint" ]] && lint_cmd="\"$tmp_lint\""
    [[ -n "$tmp_build" ]] && build_cmd="\"$tmp_build\""
  elif [[ -f "ralph/config.json" ]]; then
    local tmp_typecheck tmp_test tmp_lint tmp_build
    tmp_typecheck=$(jq -r '.config.qualityGates.typecheck // ""' ralph/config.json 2>/dev/null || echo "")
    tmp_test=$(jq -r '.config.qualityGates.test // ""' ralph/config.json 2>/dev/null || echo "")
    tmp_lint=$(jq -r '.config.qualityGates.lint // ""' ralph/config.json 2>/dev/null || echo "")
    tmp_build=$(jq -r '.config.qualityGates.build // ""' ralph/config.json 2>/dev/null || echo "")

    # Convert empty strings to null for JSON
    [[ -n "$tmp_typecheck" && "$tmp_typecheck" != "null" ]] && typecheck_cmd="\"$tmp_typecheck\""
    [[ -n "$tmp_test" && "$tmp_test" != "null" ]] && test_cmd="\"$tmp_test\""
    [[ -n "$tmp_lint" && "$tmp_lint" != "null" ]] && lint_cmd="\"$tmp_lint\""
    [[ -n "$tmp_build" && "$tmp_build" != "null" ]] && build_cmd="\"$tmp_build\""
  fi

  # Generate timestamp
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build epic filter value for JSON (null or string)
  local epic_filter_json="null"
  if [[ -n "$epic_filter" ]]; then
    epic_filter_json="\"$epic_filter\""
  fi

  # Generate prd.json content
  local prd_content
  read -r -d '' prd_content <<EOF || true
{
  "project": "$project_name",
  "loopName": "$loop_name",
  "branchName": "$branch_name",
  "description": "Loop: $loop_name",
  "generatedAt": "$timestamp",
  "sprintStatusPath": "$sprint_status_path",
  "epicFilter": $epic_filter_json,
  "config": {
    "maxIterations": $max_iterations,
    "stuckThreshold": $stuck_threshold,
    "qualityGates": {
      "typecheck": $typecheck_cmd,
      "test": $test_cmd,
      "lint": $lint_cmd,
      "build": $build_cmd
    },
    "customInstructions": null
  },
  "stats": {
    "iterationsRun": 0,
    "storiesCompleted": 0,
    "startedAt": null,
    "completedAt": null
  },
  "storyAttempts": {},
  "storyNotes": {}
}
EOF

  # Validate JSON before writing
  if ! echo "$prd_content" | jq . >/dev/null 2>&1; then
    error "Generated invalid JSON for prd.json"
    return 1
  fi

  # Write to temp file first (atomic write pattern)
  local temp_file
  temp_file=$(mktemp)
  echo "$prd_content" > "$temp_file"

  # Validate the temp file
  if ! jq . "$temp_file" >/dev/null 2>&1; then
    rm -f "$temp_file"
    error "Failed to validate generated prd.json"
    return 1
  fi

  # Move to final location
  mv "$temp_file" "$output_file"

  return 0
}
