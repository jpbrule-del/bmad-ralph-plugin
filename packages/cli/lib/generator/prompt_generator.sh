#!/usr/bin/env bash
# prompt_generator.sh - Generate prompt.md context file for Claude Code CLI

# Get LIB_DIR from main script or fallback to relative path
readonly PROMPT_GEN_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
readonly PROMPT_GEN_TEMPLATES_DIR="${TEMPLATES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../templates" && pwd)}"

# Generate prompt.md for a given loop
# Arguments:
#   $1: loop_name - Name of the loop
#   $2: loop_dir - Full path to loop directory
#   $3: epic_filter - Optional epic filter (or empty string)
generate_prompt_md() {
  local loop_name="$1"
  local loop_dir="$2"
  local epic_filter="${3:-}"

  local output_file="$loop_dir/prompt.md"

  # Check for custom template in ralph/templates/ first, fall back to default
  local custom_template="ralph/templates/prompt.md.template"
  local default_template="$PROMPT_GEN_TEMPLATES_DIR/prompt.md.template"
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

  # Try to read project name and description from sprint-status.yaml
  if [[ -f "$sprint_status_path" ]]; then
    project_name=$(yq -r '.project_name // "project"' "$sprint_status_path" 2>/dev/null || echo "project")
    local sprint_goal
    sprint_goal=$(yq -r '.sprint_goal // "Implementation sprint"' "$sprint_status_path" 2>/dev/null || echo "Implementation sprint")
  else
    # Fallback to git repo name or current directory name
    if git rev-parse --git-dir >/dev/null 2>&1; then
      project_name=$(basename "$(git rev-parse --show-toplevel)")
    else
      project_name=$(basename "$(pwd)")
    fi
    sprint_goal="Implementation sprint"
  fi

  # Get current branch
  local branch_name
  if git rev-parse --git-dir >/dev/null 2>&1; then
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  else
    branch_name="main"
  fi

  # Build architecture patterns section
  local architecture_patterns=""
  if [[ -f "docs/architecture.md" ]]; then
    architecture_patterns="See \`docs/architecture.md\` for detailed architecture documentation."
  elif [[ -f "ARCHITECTURE.md" ]]; then
    architecture_patterns="See \`ARCHITECTURE.md\` for detailed architecture documentation."
  elif [[ -f "README.md" ]]; then
    architecture_patterns="See \`README.md\` for project overview and structure."
  else
    architecture_patterns="Project architecture patterns should be discovered during implementation."
  fi

  # Build quality gates list from config.json (will be generated before this)
  local quality_gates_section=""
  local prd_file="$loop_dir/config.json"
  if [[ -f "$prd_file" ]]; then
    local typecheck_cmd test_cmd lint_cmd build_cmd
    typecheck_cmd=$(jq -r '.config.qualityGates.typecheck // ""' "$prd_file")
    test_cmd=$(jq -r '.config.qualityGates.test // ""' "$prd_file")
    lint_cmd=$(jq -r '.config.qualityGates.lint // ""' "$prd_file")
    build_cmd=$(jq -r '.config.qualityGates.build // ""' "$prd_file")

    quality_gates_section="Before committing, ALL must pass:"
    [[ -n "$typecheck_cmd" && "$typecheck_cmd" != "null" ]] && quality_gates_section+="\n- Typecheck: \`$typecheck_cmd\`"
    [[ -n "$test_cmd" && "$test_cmd" != "null" ]] && quality_gates_section+="\n- Test: \`$test_cmd\`"
    [[ -n "$lint_cmd" && "$lint_cmd" != "null" ]] && quality_gates_section+="\n- Lint: \`$lint_cmd\`"
    [[ -n "$build_cmd" && "$build_cmd" != "null" ]] && quality_gates_section+="\n- Build: \`$build_cmd\`"

    if [[ "$quality_gates_section" == "Before committing, ALL must pass:" ]]; then
      quality_gates_section="No quality gates configured. Ensure code follows project conventions."
    fi
  else
    quality_gates_section="Quality gates will be configured in config.json."
  fi

  # Build epic context
  local epic_context="All Epics"
  if [[ -n "$epic_filter" ]]; then
    local epic_name
    if [[ -f "$sprint_status_path" ]]; then
      epic_name=$(yq -r ".epics[] | select(.id == \"$epic_filter\") | .name" "$sprint_status_path" 2>/dev/null || echo "")
      if [[ -n "$epic_name" ]]; then
        epic_context="Epic: $epic_filter - $epic_name"
      else
        epic_context="Epic: $epic_filter"
      fi
    else
      epic_context="Epic: $epic_filter"
    fi
  fi

  # Read template and perform substitutions
  local template_content
  template_content=$(cat "$template_file")

  # Perform variable substitutions
  template_content="${template_content//\{\{PROJECT_NAME\}\}/$project_name}"
  template_content="${template_content//\{\{SPRINT_GOAL\}\}/$sprint_goal}"
  template_content="${template_content//\{\{BRANCH_NAME\}\}/$branch_name}"
  template_content="${template_content//\{\{SPRINT_STATUS_PATH\}\}/$sprint_status_path}"
  template_content="${template_content//\{\{ARCHITECTURE_PATTERNS\}\}/$architecture_patterns}"
  template_content="${template_content//\{\{QUALITY_GATES\}\}/$quality_gates_section}"
  template_content="${template_content//\{\{EPIC_CONTEXT\}\}/$epic_context}"

  # Write to temp file first (atomic write pattern)
  local temp_file
  temp_file=$(mktemp)
  echo -e "$template_content" > "$temp_file"

  # Move to final location
  mv "$temp_file" "$output_file"

  return 0
}
