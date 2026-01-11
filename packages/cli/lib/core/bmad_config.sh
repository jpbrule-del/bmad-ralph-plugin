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
