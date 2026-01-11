#!/usr/bin/env bash
# Sprint status analysis utilities
# Parses sprint-status.yaml to extract story information

# Get the path to sprint-status.yaml
get_sprint_status_path() {
  # Check for custom path in ralph config
  if [[ -f "ralph/config.yaml" ]]; then
    local custom_path
    custom_path=$(yq eval '.sprintStatusPath // ""' ralph/config.yaml 2>/dev/null)
    if [[ -n "$custom_path" ]] && [[ -f "$custom_path" ]]; then
      echo "$custom_path"
      return 0
    fi
  fi

  # Check for custom path in ralph config.json
  if [[ -f "ralph/config.json" ]]; then
    local custom_path
    custom_path=$(jq -r '.sprintStatusPath // ""' ralph/config.json 2>/dev/null)
    if [[ -n "$custom_path" ]] && [[ -f "$custom_path" ]]; then
      echo "$custom_path"
      return 0
    fi
  fi

  # Default path
  if [[ -f "docs/sprint-status.yaml" ]]; then
    echo "docs/sprint-status.yaml"
    return 0
  fi

  return 1
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
# Optional: filter by epic ID
# Returns: One line per story in format: "ID: title (pts) [status]"
# Usage: get_pending_stories [epic_id]
get_pending_stories() {
  local epic_filter="${1:-}"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  # Build yq filter for pending stories (not-started or in-progress)
  local filter='[.epics[]'
  if [[ -n "$epic_filter" ]]; then
    filter="$filter | select(.id == \"$epic_filter\")"
  fi
  filter="$filter | .stories[] | select(.status == \"not-started\" or .status == \"in-progress\") | {\"id\": .id, \"title\": .title, \"points\": .points, \"status\": .status}]"

  # Extract stories as JSON array and format with jq
  yq eval -o json "$filter" "$sprint_file" 2>/dev/null | jq -r '.[] | "\(.id): \(.title) (\(.points) pts) [\(.status)]"' 2>/dev/null
}

# Get story count (pending stories)
# Usage: get_pending_story_count [epic_id]
get_pending_story_count() {
  local epic_filter="${1:-}"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    echo "0"
    return 1
  fi

  # Build yq filter for pending stories (not-started or in-progress)
  local filter='.epics[]'
  if [[ -n "$epic_filter" ]]; then
    filter="$filter | select(.id == \"$epic_filter\")"
  fi
  filter="$filter | .stories[] | select(.status == \"not-started\" or .status == \"in-progress\") | .id"

  # Count stories
  local count
  count=$(yq eval "$filter" "$sprint_file" 2>/dev/null | wc -l | tr -d ' ')
  echo "${count:-0}"
}

# Get story details by ID
# Usage: get_story <story_id>
# Outputs YAML for the story
get_story() {
  local story_id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  yq eval ".epics[].stories[] | select(.id == \"$story_id\")" "$sprint_file" 2>/dev/null
}

# Get specific field from a story
# Usage: get_story_field <story_id> <field>
# Example: get_story_field STORY-001 title
get_story_field() {
  local story_id="$1"
  local field="$2"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  yq eval ".epics[].stories[] | select(.id == \"$story_id\") | .$field" "$sprint_file" 2>/dev/null
}

# List all epic IDs
get_all_epics() {
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  yq eval '.epics[].id' "$sprint_file" 2>/dev/null
}

# Validate epic exists
# Usage: epic_exists <epic_id>
epic_exists() {
  local epic_id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  local result
  result=$(yq eval ".epics[] | select(.id == \"$epic_id\") | .id" "$sprint_file" 2>/dev/null)

  if [[ -n "$result" ]]; then
    return 0
  else
    return 1
  fi
}

# Get epic name
get_epic_name() {
  local epic_id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  yq eval ".epics[] | select(.id == \"$epic_id\") | .name" "$sprint_file" 2>/dev/null
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
get_story_acceptance_criteria() {
  local story_id="$1"
  local sprint_file

  sprint_file=$(get_sprint_status_path)
  if [[ -z "$sprint_file" ]]; then
    return 1
  fi

  yq eval ".epics[].stories[] | select(.id == \"$story_id\") | .acceptance_criteria[]" "$sprint_file" 2>/dev/null
}
