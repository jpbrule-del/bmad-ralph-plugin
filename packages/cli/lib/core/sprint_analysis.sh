#!/usr/bin/env bash
# Sprint status analysis utilities
# Parses sprint-status.yaml to extract story information

# Get LIB_DIR from main script or fallback to relative path
readonly SPRINT_ANALYSIS_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

# Source bmad_config utilities
# shellcheck source=lib/core/bmad_config.sh
source "$SPRINT_ANALYSIS_LIB_DIR/core/bmad_config.sh"

# Get the path to sprint-status.yaml
# Uses get_bmad_sprint_status_path which checks:
# 1. bmad/config.yaml (bmm.sprint_status_file)
# 2. ralph/config.yaml (bmad.sprint_status_path)
# 3. ralph/config.json (sprintStatusPath)
# 4. Falls back to docs/sprint-status.yaml
get_sprint_status_path() {
  get_bmad_sprint_status_path
}

# Validate sprint-status.yaml is readable
validate_sprint_status() {
  local sprint_file
  sprint_file=$(get_sprint_status_path)

  if [[ -z "$sprint_file" ]]; then
    error "Sprint status file not found"
    echo ""
    echo "Expected file at: docs/sprint-status.yaml"
    echo "Or configure custom path in ralph/config.yaml"
    return 1
  fi

  # Test YAML validity
  if ! yq eval '.' "$sprint_file" >/dev/null 2>&1; then
    error "Sprint status file is malformed or not valid YAML"
    echo ""
    echo "File: $sprint_file"
    echo ""
    echo "Run 'yq eval . $sprint_file' to see parsing errors"
    return 1
  fi

  return 0
}

# Get all pending stories (status != completed)
# Optional: filter by epic ID or sprint number
# Returns: One line per story in format: "ID: title (pts) [status]"
# Usage: get_pending_stories [epic_id_or_sprint]
# Supports both BMAD formats:
#   - epics[].stories[] with status "not-started"/"in-progress" and .id field
#   - sprints[].stories[] with status "not_started"/"in_progress" and .story_id field
get_pending_stories() {
  local filter_value="${1:-}"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Detect format: check if file has .epics or .sprints
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    # Original epics format
    local filter='[.epics[]'
    if [[ -n "$filter_value" ]]; then
      filter="$filter | select(.id == \"$filter_value\")"
    fi
    filter="$filter | .stories[] | select(.status == \"not-started\" or .status == \"in-progress\" or .status == \"not_started\" or .status == \"in_progress\") | {\"id\": .id, \"title\": .title, \"points\": .points, \"status\": .status}]"
    yq eval -o json "$filter" "$sprint_file" 2>/dev/null | jq -r '.[] | "\(.id): \(.title) (\(.points) pts) [\(.status)]"' 2>/dev/null
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    # BMAD sprints format (story_id field, underscore status values)
    local filter='[.sprints[]'
    if [[ -n "$filter_value" ]]; then
      # Filter by sprint number if numeric, otherwise skip filtering
      if [[ "$filter_value" =~ ^[0-9]+$ ]]; then
        filter="$filter | select(.sprint_number == $filter_value)"
      fi
    fi
    filter="$filter | .stories[] | select(.status == \"not_started\" or .status == \"in_progress\" or .status == \"not-started\" or .status == \"in-progress\") | {\"id\": (.story_id // .id), \"title\": .title, \"points\": .points, \"status\": .status}]"
    yq eval -o json "$filter" "$sprint_file" 2>/dev/null | jq -r '.[] | "\(.id): \(.title) (\(.points) pts) [\(.status)]"' 2>/dev/null
  else
    # No stories found
    return 1
  fi
}

# Get story count (pending stories)
# Usage: get_pending_story_count [filter_value]
# Supports both BMAD formats (epics and sprints)
get_pending_story_count() {
  local filter_value="${1:-}"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    echo "0"
    return 1
  fi

  # Detect format: check if file has .epics or .sprints
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  local filter count

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    # Original epics format
    filter='.epics[]'
    if [[ -n "$filter_value" ]]; then
      filter="$filter | select(.id == \"$filter_value\")"
    fi
    filter="$filter | .stories[] | select(.status == \"not-started\" or .status == \"in-progress\" or .status == \"not_started\" or .status == \"in_progress\") | .id"
    count=$(yq eval "$filter" "$sprint_file" 2>/dev/null | wc -l | tr -d ' ')
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    # BMAD sprints format
    filter='.sprints[]'
    if [[ -n "$filter_value" ]] && [[ "$filter_value" =~ ^[0-9]+$ ]]; then
      filter="$filter | select(.sprint_number == $filter_value)"
    fi
    filter="$filter | .stories[] | select(.status == \"not_started\" or .status == \"in_progress\" or .status == \"not-started\" or .status == \"in-progress\") | (.story_id // .id)"
    count=$(yq eval "$filter" "$sprint_file" 2>/dev/null | wc -l | tr -d ' ')
  else
    count=0
  fi

  echo "${count:-0}"
}

# Get story details by ID
# Usage: get_story <story_id>
# Outputs YAML for the story
# Supports both BMAD formats (epics and sprints)
get_story() {
  local story_id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Detect format
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    yq eval ".epics[].stories[] | select(.id == \"$story_id\")" "$sprint_file" 2>/dev/null
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    yq eval ".sprints[].stories[] | select(.story_id == \"$story_id\" or .id == \"$story_id\")" "$sprint_file" 2>/dev/null
  fi
}

# Get specific field from a story
# Usage: get_story_field <story_id> <field>
# Example: get_story_field STORY-001 title
# Supports both BMAD formats (epics and sprints)
get_story_field() {
  local story_id="$1"
  local field="$2"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Detect format
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    yq eval ".epics[].stories[] | select(.id == \"$story_id\") | .$field" "$sprint_file" 2>/dev/null
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    yq eval ".sprints[].stories[] | select(.story_id == \"$story_id\" or .id == \"$story_id\") | .$field" "$sprint_file" 2>/dev/null
  fi
}

# List all epic IDs (or sprint numbers in BMAD sprints format)
# Returns: epic IDs or sprint numbers depending on format
get_all_epics() {
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Detect format
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    yq eval '.epics[].id' "$sprint_file" 2>/dev/null
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    # Return sprint numbers as identifiers
    yq eval '.sprints[].sprint_number' "$sprint_file" 2>/dev/null
  fi
}

# Validate epic/sprint exists
# Usage: epic_exists <epic_id_or_sprint_number>
epic_exists() {
  local id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Detect format
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  local result

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    result=$(yq eval ".epics[] | select(.id == \"$id\") | .id" "$sprint_file" 2>/dev/null)
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    # Check by sprint number
    if [[ "$id" =~ ^[0-9]+$ ]]; then
      result=$(yq eval ".sprints[] | select(.sprint_number == $id) | .sprint_number" "$sprint_file" 2>/dev/null)
    fi
  fi

  if [[ -n "$result" ]]; then
    return 0
  else
    return 1
  fi
}

# Get epic/sprint name
# Usage: get_epic_name <epic_id_or_sprint_number>
get_epic_name() {
  local id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Detect format
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    yq eval ".epics[] | select(.id == \"$id\") | .name" "$sprint_file" 2>/dev/null
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    # Return sprint goal as name
    if [[ "$id" =~ ^[0-9]+$ ]]; then
      yq eval ".sprints[] | select(.sprint_number == $id) | .goal" "$sprint_file" 2>/dev/null
    fi
  fi
}

# Print story summary (for display purposes)
# Usage: print_story_summary <story_line>
# Story line format: "ID: title (pts) [status]"
print_story_summary() {
  local story_line="$1"
  echo "  $story_line"
}

# Extract acceptance criteria for a story
# Usage: get_story_acceptance_criteria <story_id>
# Supports both BMAD formats (epics and sprints)
# Note: In BMAD sprints format, acceptance_criteria may be in story markdown files, not sprint-status.yaml
get_story_acceptance_criteria() {
  local story_id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Detect format
  local has_epics has_sprints
  has_epics=$(yq eval '.epics | length' "$sprint_file" 2>/dev/null)
  has_sprints=$(yq eval '.sprints | length' "$sprint_file" 2>/dev/null)

  if [[ "$has_epics" != "0" ]] && [[ "$has_epics" != "null" ]] && [[ -n "$has_epics" ]]; then
    yq eval ".epics[].stories[] | select(.id == \"$story_id\") | .acceptance_criteria[]" "$sprint_file" 2>/dev/null
  elif [[ "$has_sprints" != "0" ]] && [[ "$has_sprints" != "null" ]] && [[ -n "$has_sprints" ]]; then
    yq eval ".sprints[].stories[] | select(.story_id == \"$story_id\" or .id == \"$story_id\") | .acceptance_criteria[]" "$sprint_file" 2>/dev/null
  fi
}
