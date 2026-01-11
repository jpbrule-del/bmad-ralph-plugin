#!/usr/bin/env bash
# ralph init - Initialize ralph in a BMAD project (v2: BMAD-native)

# Get LIB_DIR from main script or fallback to relative path
readonly INIT_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

# Source bmad_config utilities
# shellcheck source=lib/core/bmad_config.sh
source "$INIT_LIB_DIR/core/bmad_config.sh"

# Ralph version
readonly RALPH_VERSION="2.0"

cmd_init() {
  local force=false
  local install_agent=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=true
        shift
        ;;
      --install-agent)
        install_agent=true
        shift
        ;;
      *)
        error "Unknown option: $1"
        echo "Usage: ralph init [--force] [--install-agent]"
        exit 1
        ;;
    esac
  done

  # Detect BMAD project - requires bmad/config.yaml for v2
  if ! is_bmad_project; then
    error "Not a BMAD project"
    echo ""
    echo "Ralph v2 requires a BMAD project with:"
    echo "  • bmad/config.yaml (required)"
    echo "  • docs/sprint-status.yaml (required)"
    echo ""
    echo "Initialize BMAD first, then run 'ralph init'"
    exit 1
  fi

  # v2 requires bmad/config.yaml specifically
  if [[ ! -f "bmad/config.yaml" ]]; then
    error "bmad/config.yaml not found"
    echo ""
    echo "Ralph v2 requires bmad/config.yaml to store configuration."
    echo "Please ensure your BMAD project has this file."
    exit 1
  fi

  # Check if already initialized (v2 style: ralph section in bmad/config.yaml)
  if has_ralph_config && [[ "$force" != "true" ]]; then
    warning "Ralph already initialized in this project"
    echo ""
    echo "Ralph configuration exists in bmad/config.yaml"
    echo "Use 'ralph init --force' to reinitialize"
    exit 0
  fi

  # Check for v1 installation that needs migration
  if [[ -f "ralph/config.yaml" ]] && [[ "$force" != "true" ]]; then
    warning "Found Ralph v1 configuration (ralph/config.yaml)"
    echo ""
    echo "Ralph v2 stores configuration in bmad/config.yaml"
    echo "Your existing configuration will be migrated automatically."
    echo ""
    echo "Use 'ralph init --force' to reinitialize (will overwrite settings)"
    exit 0
  fi

  # Create directory structure
  info "Initializing Ralph v2 in $(basename "$(pwd)")..."

  mkdir -p ralph/loops
  mkdir -p ralph/archive
  success "Created directory structure"

  # Add ralph section to bmad/config.yaml
  extend_bmad_config
  success "Added ralph configuration to bmad/config.yaml"

  # Install agent files if requested
  if [[ "$install_agent" == "true" ]]; then
    echo ""
    info "Installing ralph agent files..."
    install_agent_files
  fi

  echo ""
  success "Ralph v2 initialized successfully!"
  echo ""
  echo "Configuration stored in: bmad/config.yaml (ralph: section)"
  echo ""
  echo "Next steps:"
  echo "  1. Review bmad/config.yaml ralph section and adjust defaults if needed"
  echo "  2. Create a loop: ralph create <loop-name>"
  echo "  3. Run the loop: ralph run <loop-name>"

  if [[ "$install_agent" == "true" ]]; then
    echo ""
    echo "Agent integration installed:"
    echo "  • bmm/agents/ralph.md - Agent definition"
    echo "  • docs/bmm-workflow-status.yaml - Workflow registration"
  fi
}

# Check if current directory is a BMAD project
is_bmad_project() {
  [[ -f "docs/sprint-status.yaml" ]] || [[ -f "bmad/config.yaml" ]]
}

# Add ralph section to bmad/config.yaml (v2 style)
extend_bmad_config() {
  local bmad_config="bmad/config.yaml"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create temp file for atomic write
  local temp_file
  temp_file=$(mktemp)

  # Add ralph section to bmad/config.yaml
  yq eval "
    .ralph.version = \"$RALPH_VERSION\" |
    .ralph.initialized_at = \"$timestamp\" |
    .ralph.defaults.max_iterations = 50 |
    .ralph.defaults.stuck_threshold = 3 |
    .ralph.defaults.quality_gates.typecheck = null |
    .ralph.defaults.quality_gates.test = null |
    .ralph.defaults.quality_gates.lint = null |
    .ralph.defaults.quality_gates.build = null |
    .ralph.loops_dir = \"ralph/loops\" |
    .ralph.archive_dir = \"ralph/archive\"
  " "$bmad_config" > "$temp_file"

  # Validate and apply
  if yq eval '.' "$temp_file" >/dev/null 2>&1; then
    mv "$temp_file" "$bmad_config"
  else
    rm -f "$temp_file"
    error "Failed to update bmad/config.yaml"
    return 1
  fi
}

# Legacy: Create config.yaml with defaults (kept for reference, not used in v2)
create_config_yaml_legacy() {
  local project_name
  local sprint_status_path
  local bmad_config_path

  # Use BMAD config detection for project name and paths
  project_name=$(get_bmad_project_name)
  sprint_status_path=$(get_bmad_sprint_status_path || echo "")
  bmad_config_path=$(get_bmad_config_path || echo "")

  # Write config using atomic pattern (temp + rename)
  local temp_file="ralph/config.yaml.tmp.$$"

  cat > "$temp_file" <<EOF
version: "1.0"
project_name: "$project_name"
created_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

bmad:
  sprint_status_path: "$sprint_status_path"
  config_path: "$bmad_config_path"

defaults:
  max_iterations: 50
  stuck_threshold: 3
  quality_gates:
    typecheck: null
    test: null
    lint: true
    build: true
EOF

  # Atomic rename
  mv "$temp_file" "ralph/config.yaml"
}

# Install ralph agent files into project BMAD configuration
install_agent_files() {
  local install_dir="$TEMPLATES_DIR/install"

  # Validate install directory exists
  if [[ ! -d "$install_dir" ]]; then
    error "Agent files not found in ralph installation"
    echo "Expected at: $install_dir"
    return 1
  fi

  # Create bmm/agents directory
  mkdir -p bmm/agents
  success "Created bmm/agents directory"

  # Copy ralph agent definition
  if [[ -f "$install_dir/bmm/agents/ralph.md" ]]; then
    cp "$install_dir/bmm/agents/ralph.md" bmm/agents/
    success "Installed bmm/agents/ralph.md"
  else
    warning "ralph.md not found in install directory"
  fi

  # Create or update workflow status file
  if [[ -f "docs/bmm-workflow-status.yaml" ]]; then
    # Update existing file
    update_workflow_status_file
  else
    # Create new file
    create_workflow_status_file
  fi
}

# Create new bmm-workflow-status.yaml with ralph workflow
create_workflow_status_file() {
  local project_name
  project_name="$(basename "$(pwd)")"

  mkdir -p docs

  # Write workflow status using atomic pattern
  local temp_file="docs/bmm-workflow-status.yaml.tmp.$$"

  cat > "$temp_file" <<'EOF'
# BMM Workflow Status
# Generated by ralph init --install-agent
# For workflow documentation: https://bmad.ai/workflows

project_name: "PROJECT_NAME"
project_type: "PROJECT_TYPE"
initialized: "INIT_DATE"

workflows:
  # Phase 5: Autonomous Execution
  phase_5:
    name: "Autonomous Execution"
    workflows:
      ralph:
        status: "bmm/agents/ralph.md"
        description: "Autonomous loop execution for story implementation"
        inputs:
          - "docs/sprint-status.yaml (stories and acceptance criteria)"
          - "docs/prd-*.md (requirements and context)"
          - "docs/architecture-*.md (patterns and tech stack)"
        outputs:
          - "Implemented stories with passing quality gates"
          - "Updated docs/sprint-status.yaml (story completion)"
          - "ralph/progress.txt (iteration log)"
          - "Git commits (one per completed story)"
        invocation: "/ralph"
        phase_position: "5"
        prerequisites:
          - "Phase 4 sprint planning completed"
          - "Quality gates configured"
          - "Stories have acceptance criteria"

current_phase: 5
last_updated: "UPDATE_DATE"
EOF

  # Replace placeholders
  sed -i.bak \
    -e "s/PROJECT_NAME/$project_name/g" \
    -e "s/PROJECT_TYPE/project/g" \
    -e "s/INIT_DATE/$(date -u +"%Y-%m-%d")/g" \
    -e "s/UPDATE_DATE/$(date -u +"%Y-%m-%dT%H:%M:%SZ")/g" \
    "$temp_file"

  rm -f "$temp_file.bak"

  # Atomic rename
  mv "$temp_file" "docs/bmm-workflow-status.yaml"
  success "Created docs/bmm-workflow-status.yaml"
}

# Update existing bmm-workflow-status.yaml with ralph workflow
update_workflow_status_file() {
  # Check if ralph workflow already exists
  if grep -q "ralph:" docs/bmm-workflow-status.yaml 2>/dev/null; then
    info "Ralph workflow already registered in docs/bmm-workflow-status.yaml"
    return 0
  fi

  # Create backup
  cp docs/bmm-workflow-status.yaml docs/bmm-workflow-status.yaml.backup

  # Use yq to add ralph workflow under phase_5.workflows
  local temp_file="docs/bmm-workflow-status.yaml.tmp.$$"
  local workflow_template="$TEMPLATES_DIR/install/ralph-workflow.yaml"

  if [[ ! -f "$workflow_template" ]]; then
    warning "Workflow template not found, skipping workflow registration"
    return 1
  fi

  # Check if phase_5 exists
  if ! yq eval '.workflows.phase_5' docs/bmm-workflow-status.yaml >/dev/null 2>&1; then
    # Add phase_5 section
    yq eval '.workflows.phase_5 = {"name": "Autonomous Execution", "workflows": {}}' \
      docs/bmm-workflow-status.yaml > "$temp_file"
    mv "$temp_file" docs/bmm-workflow-status.yaml
  fi

  # Read ralph workflow config and merge
  yq eval-all 'select(fileIndex == 0).workflows.phase_5.workflows.ralph = select(fileIndex == 1).ralph | select(fileIndex == 0)' \
    docs/bmm-workflow-status.yaml "$workflow_template" > "$temp_file"

  # Update last_updated timestamp
  yq eval ".last_updated = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" \
    "$temp_file" > "${temp_file}.2"

  # Atomic rename
  mv "${temp_file}.2" docs/bmm-workflow-status.yaml
  rm -f "$temp_file"

  success "Updated docs/bmm-workflow-status.yaml with ralph workflow"
}
