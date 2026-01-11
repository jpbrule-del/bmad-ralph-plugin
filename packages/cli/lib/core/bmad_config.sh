#!/usr/bin/env bash
# BMAD config detection and reading utilities
# Reads bmad/config.yaml to detect project configuration

# Get BMAD config path
# Checks for bmad/config.yaml in project root
get_bmad_config_path() {
  if [[ -f "bmad/config.yaml" ]]; then
    echo "bmad/config.yaml"
    return 0
  fi
  return 1
}

# Check if BMAD config exists
has_bmad_config() {
  [[ -f "bmad/config.yaml" ]]
}

# Get sprint status file path from BMAD config
# Falls back to ralph/config.yaml, ralph/config.json, then docs/sprint-status.yaml
get_bmad_sprint_status_path() {
  local path=""

  # Check bmad/config.yaml first
  if [[ -f "bmad/config.yaml" ]]; then
    path=$(yq eval '.bmm.sprint_status_file // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$path" ]] && [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  fi

  # Check ralph/config.yaml
  if [[ -f "ralph/config.yaml" ]]; then
    path=$(yq eval '.bmad.sprint_status_path // ""' ralph/config.yaml 2>/dev/null)
    if [[ -n "$path" ]] && [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  fi

  # Check ralph/config.json
  if [[ -f "ralph/config.json" ]]; then
    path=$(jq -r '.sprintStatusPath // ""' ralph/config.json 2>/dev/null)
    if [[ -n "$path" ]] && [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  fi

  # Fall back to default
  if [[ -f "docs/sprint-status.yaml" ]]; then
    echo "docs/sprint-status.yaml"
    return 0
  fi

  return 1
}

# Get output folder path from BMAD config
# Returns the output folder path or "docs" as default
get_bmad_output_folder() {
  local folder="docs"

  if [[ -f "bmad/config.yaml" ]]; then
    local config_folder
    config_folder=$(yq eval '.output_folder // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$config_folder" ]]; then
      folder="$config_folder"
    fi
  fi

  echo "$folder"
}

# Get workflow status file path from BMAD config
# Falls back to docs/bmm-workflow-status.yaml
get_bmad_workflow_status_path() {
  local path=""

  if [[ -f "bmad/config.yaml" ]]; then
    path=$(yq eval '.bmm.workflow_status_file // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$path" ]]; then
      echo "$path"
      return 0
    fi
  fi

  # Fall back to default
  echo "docs/bmm-workflow-status.yaml"
  return 0
}

# Get docs path from BMAD config
# Falls back to "docs"
get_bmad_docs_path() {
  local path="docs"

  if [[ -f "bmad/config.yaml" ]]; then
    local config_path
    config_path=$(yq eval '.paths.docs // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$config_path" ]]; then
      path="$config_path"
    fi
  fi

  echo "$path"
}

# Get stories path from BMAD config
# Falls back to "docs/stories"
get_bmad_stories_path() {
  local path=""

  if [[ -f "bmad/config.yaml" ]]; then
    path=$(yq eval '.paths.stories // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$path" ]]; then
      echo "$path"
      return 0
    fi
  fi

  # Fall back to default based on output_folder
  local output_folder
  output_folder=$(get_bmad_output_folder)
  echo "${output_folder}/stories"
  return 0
}

# Get project name from BMAD config
# Falls back to git repo name or current directory name
get_bmad_project_name() {
  local name=""

  if [[ -f "bmad/config.yaml" ]]; then
    name=$(yq eval '.project_name // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$name" ]]; then
      echo "$name"
      return 0
    fi
  fi

  # Try sprint-status.yaml
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)
  if [[ -n "$sprint_file" ]] && [[ -f "$sprint_file" ]]; then
    name=$(yq eval '.project_name // ""' "$sprint_file" 2>/dev/null)
    if [[ -n "$name" ]]; then
      echo "$name"
      return 0
    fi
  fi

  # Fall back to git repo or directory name
  if git rev-parse --git-dir >/dev/null 2>&1; then
    basename "$(git rev-parse --show-toplevel)"
  else
    basename "$(pwd)"
  fi
}

# ============================================================================
# Ralph Configuration (v2) - Read from bmad/config.yaml ralph: section
# ============================================================================

# Check if Ralph is initialized (v2 style: ralph section in bmad/config.yaml)
has_ralph_config() {
  if [[ -f "bmad/config.yaml" ]]; then
    local version
    version=$(yq eval '.ralph.version // ""' bmad/config.yaml 2>/dev/null)
    [[ -n "$version" ]]
  else
    return 1
  fi
}

# Check if Ralph is initialized (either v1 or v2)
is_ralph_initialized() {
  # v2: Check for ralph section in bmad/config.yaml
  if has_ralph_config; then
    return 0
  fi

  # v1: Check for ralph/config.yaml (backward compat, will be migrated)
  if [[ -f "ralph/config.yaml" ]]; then
    return 0
  fi

  return 1
}

# Get Ralph default max_iterations
# Reads from bmad/config.yaml ralph.defaults.max_iterations
# Falls back to 50
get_ralph_max_iterations() {
  local value=50

  if [[ -f "bmad/config.yaml" ]]; then
    local config_value
    config_value=$(yq eval '.ralph.defaults.max_iterations // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$config_value" ]] && [[ "$config_value" != "null" ]]; then
      value="$config_value"
    fi
  fi

  echo "$value"
}

# Get Ralph default stuck_threshold
# Reads from bmad/config.yaml ralph.defaults.stuck_threshold
# Falls back to 3
get_ralph_stuck_threshold() {
  local value=3

  if [[ -f "bmad/config.yaml" ]]; then
    local config_value
    config_value=$(yq eval '.ralph.defaults.stuck_threshold // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$config_value" ]] && [[ "$config_value" != "null" ]]; then
      value="$config_value"
    fi
  fi

  echo "$value"
}

# Get Ralph quality gates from bmad/config.yaml
# Returns JSON object with typecheck, test, lint, build values
get_ralph_quality_gates() {
  local typecheck="null"
  local test="null"
  local lint="null"
  local build="null"

  if [[ -f "bmad/config.yaml" ]]; then
    local tmp_val

    tmp_val=$(yq eval '.ralph.defaults.quality_gates.typecheck // null' bmad/config.yaml 2>/dev/null)
    if [[ -n "$tmp_val" ]] && [[ "$tmp_val" != "null" ]]; then
      typecheck="\"$tmp_val\""
    fi

    tmp_val=$(yq eval '.ralph.defaults.quality_gates.test // null' bmad/config.yaml 2>/dev/null)
    if [[ -n "$tmp_val" ]] && [[ "$tmp_val" != "null" ]]; then
      test="\"$tmp_val\""
    fi

    tmp_val=$(yq eval '.ralph.defaults.quality_gates.lint // null' bmad/config.yaml 2>/dev/null)
    if [[ -n "$tmp_val" ]] && [[ "$tmp_val" != "null" ]]; then
      lint="\"$tmp_val\""
    fi

    tmp_val=$(yq eval '.ralph.defaults.quality_gates.build // null' bmad/config.yaml 2>/dev/null)
    if [[ -n "$tmp_val" ]] && [[ "$tmp_val" != "null" ]]; then
      build="\"$tmp_val\""
    fi
  fi

  echo "{\"typecheck\": $typecheck, \"test\": $test, \"lint\": $lint, \"build\": $build}"
}

# Get Ralph loops directory
# Reads from bmad/config.yaml ralph.loops_dir
# Falls back to ralph/loops
get_ralph_loops_dir() {
  local dir="ralph/loops"

  if [[ -f "bmad/config.yaml" ]]; then
    local config_dir
    config_dir=$(yq eval '.ralph.loops_dir // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$config_dir" ]] && [[ "$config_dir" != "null" ]]; then
      dir="$config_dir"
    fi
  fi

  echo "$dir"
}

# Get Ralph archive directory
# Reads from bmad/config.yaml ralph.archive_dir
# Falls back to ralph/archive
get_ralph_archive_dir() {
  local dir="ralph/archive"

  if [[ -f "bmad/config.yaml" ]]; then
    local config_dir
    config_dir=$(yq eval '.ralph.archive_dir // ""' bmad/config.yaml 2>/dev/null)
    if [[ -n "$config_dir" ]] && [[ "$config_dir" != "null" ]]; then
      dir="$config_dir"
    fi
  fi

  echo "$dir"
}

# Get loop info from sprint-status.yaml
# Arguments: $1 = loop_name
# Returns JSON with loop metadata or empty if not found
get_loop_from_sprint_status() {
  local loop_name="$1"
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)

  if [[ ! -f "$sprint_file" ]]; then
    return 1
  fi

  yq eval ".ralph_loops[] | select(.name == \"$loop_name\")" "$sprint_file" 2>/dev/null
}

# Get all loops from sprint-status.yaml
# Returns array of loop objects
get_all_loops_from_sprint_status() {
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)

  if [[ ! -f "$sprint_file" ]]; then
    echo "[]"
    return 0
  fi

  yq eval '.ralph_loops // []' "$sprint_file" 2>/dev/null
}

# Update loop status in sprint-status.yaml
# Arguments: $1 = loop_name, $2 = status (active, paused, completed, archived)
update_loop_status_in_sprint() {
  local loop_name="$1"
  local new_status="$2"
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)

  if [[ ! -f "$sprint_file" ]]; then
    return 1
  fi

  local temp_file
  temp_file=$(mktemp)

  yq eval "
    (.ralph_loops[] | select(.name == \"$loop_name\")).status = \"$new_status\"
  " "$sprint_file" > "$temp_file"

  if yq eval '.' "$temp_file" >/dev/null 2>&1; then
    mv "$temp_file" "$sprint_file"
    return 0
  else
    rm -f "$temp_file"
    return 1
  fi
}

# Update loop stats in sprint-status.yaml
# Arguments: $1 = loop_name, $2 = iterations_run, $3 = stories_completed
update_loop_stats_in_sprint() {
  local loop_name="$1"
  local iterations_run="$2"
  local stories_completed="$3"
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)

  if [[ ! -f "$sprint_file" ]]; then
    return 1
  fi

  local temp_file
  temp_file=$(mktemp)

  yq eval "
    (.ralph_loops[] | select(.name == \"$loop_name\")).stats.iterations_run = $iterations_run |
    (.ralph_loops[] | select(.name == \"$loop_name\")).stats.stories_completed = $stories_completed
  " "$sprint_file" > "$temp_file"

  if yq eval '.' "$temp_file" >/dev/null 2>&1; then
    mv "$temp_file" "$sprint_file"
    return 0
  else
    rm -f "$temp_file"
    return 1
  fi
}

# Add a new loop to sprint-status.yaml
# Arguments: $1 = loop_name, $2 = branch_name
add_loop_to_sprint_status() {
  local loop_name="$1"
  local branch_name="$2"
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)

  if [[ ! -f "$sprint_file" ]]; then
    return 1
  fi

  local temp_file
  temp_file=$(mktemp)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Check if ralph_loops exists, if not create it
  if ! yq eval '.ralph_loops' "$sprint_file" 2>/dev/null | grep -q "name"; then
    yq eval '.ralph_loops = []' "$sprint_file" > "$temp_file"
    mv "$temp_file" "$sprint_file"
    temp_file=$(mktemp)
  fi

  # Add the new loop
  yq eval "
    .ralph_loops += [{
      \"name\": \"$loop_name\",
      \"branch\": \"$branch_name\",
      \"created_at\": \"$timestamp\",
      \"status\": \"active\",
      \"stats\": {
        \"iterations_run\": 0,
        \"stories_completed\": 0
      }
    }]
  " "$sprint_file" > "$temp_file"

  if yq eval '.' "$temp_file" >/dev/null 2>&1; then
    mv "$temp_file" "$sprint_file"
    return 0
  else
    rm -f "$temp_file"
    return 1
  fi
}
