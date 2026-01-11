#!/usr/bin/env bash
# loop_generator.sh - Generate loop.sh orchestration script

# Get LIB_DIR from main script or fallback to relative path
readonly LOOP_GEN_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
readonly LOOP_GEN_TEMPLATES_DIR="${TEMPLATES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../templates" && pwd)}"

# Generate loop.sh for a given loop
# Arguments:
#   $1: loop_name - Name of the loop
#   $2: loop_dir - Full path to loop directory
#   $3: epic_filter - Optional epic filter (or empty string)
#   $4: max_iterations - Max iterations (default: 50)
#   $5: stuck_threshold - Stuck threshold (default: 3)
generate_loop_sh() {
  local loop_name="$1"
  local loop_dir="$2"
  local epic_filter="${3:-}"
  local max_iterations="${4:-50}"
  local stuck_threshold="${5:-3}"

  local output_file="$loop_dir/loop.sh"

  # Check for custom template in ralph/templates/ first, fall back to default
  local custom_template="ralph/templates/loop.sh.template"
  local default_template="$LOOP_GEN_TEMPLATES_DIR/loop.sh.template"
  local template_file="$default_template"

  if [[ -f "$custom_template" ]]; then
    template_file="$custom_template"
    info "Using custom template: $custom_template"
  fi

  # Check template exists
  if [[ ! -f "$template_file" ]]; then
    error "Template not found: $template_file"
    return 1
  fi

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

  # Use expected loop branch name (ralph/<loop_name>)
  local branch_name="ralph/$loop_name"

  # Read quality gate commands from ralph/config.yaml or use defaults
  local typecheck_cmd=""
  local test_cmd=""
  local lint_cmd=""
  local build_cmd=""

  if [[ -f "ralph/config.yaml" ]]; then
    typecheck_cmd=$(yq -r '.qualityGates.typecheck // ""' ralph/config.yaml 2>/dev/null || echo "")
    test_cmd=$(yq -r '.qualityGates.test // ""' ralph/config.yaml 2>/dev/null || echo "")
    lint_cmd=$(yq -r '.qualityGates.lint // ""' ralph/config.yaml 2>/dev/null || echo "")
    build_cmd=$(yq -r '.qualityGates.build // ""' ralph/config.yaml 2>/dev/null || echo "")
  elif [[ -f "ralph/config.json" ]]; then
    typecheck_cmd=$(jq -r '.qualityGates.typecheck // ""' ralph/config.json 2>/dev/null || echo "")
    test_cmd=$(jq -r '.qualityGates.test // ""' ralph/config.json 2>/dev/null || echo "")
    lint_cmd=$(jq -r '.qualityGates.lint // ""' ralph/config.json 2>/dev/null || echo "")
    build_cmd=$(jq -r '.qualityGates.build // ""' ralph/config.json 2>/dev/null || echo "")
  fi

  # Generate timestamp
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read template and perform substitutions
  local template_content
  template_content=$(cat "$template_file")

  # Perform variable substitutions
  template_content="${template_content//\{\{TIMESTAMP\}\}/$timestamp}"
  template_content="${template_content//\{\{PROJECT_NAME\}\}/$project_name}"
  template_content="${template_content//\{\{BRANCH_NAME\}\}/$branch_name}"
  template_content="${template_content//\{\{MAX_ITERATIONS\}\}/$max_iterations}"
  template_content="${template_content//\{\{STUCK_THRESHOLD\}\}/$stuck_threshold}"
  template_content="${template_content//\{\{SPRINT_STATUS_FILE\}\}/$sprint_status_path}"
  template_content="${template_content//\{\{TYPECHECK_CMD\}\}/$typecheck_cmd}"
  template_content="${template_content//\{\{TEST_CMD\}\}/$test_cmd}"
  template_content="${template_content//\{\{LINT_CMD\}\}/$lint_cmd}"
  template_content="${template_content//\{\{BUILD_CMD\}\}/$build_cmd}"

  # Write to temp file first (atomic write pattern)
  local temp_file
  temp_file=$(mktemp)
  echo "$template_content" > "$temp_file"

  # Move to final location
  mv "$temp_file" "$output_file"

  # Make executable
  chmod +x "$output_file"

  return 0
}
