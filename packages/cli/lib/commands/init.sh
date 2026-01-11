#!/usr/bin/env bash
# ralph init - Initialize ralph in a BMAD project

cmd_init() {
  local force=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=true
        shift
        ;;
      *)
        error "Unknown option: $1"
        echo "Usage: ralph init [--force]"
        exit 1
        ;;
    esac
  done

  # Detect BMAD project
  if ! is_bmad_project; then
    error "Not a BMAD project"
    echo ""
    echo "Ralph requires a BMAD project with one of:"
    echo "  • docs/sprint-status.yaml"
    echo "  • bmad/config.yaml"
    echo ""
    echo "Initialize BMAD first, then run 'ralph init'"
    exit 1
  fi

  # Check if already initialized
  if [[ -f "ralph/config.yaml" ]] && [[ "$force" != "true" ]]; then
    warning "Ralph already initialized in this project"
    echo ""
    echo "ralph/config.yaml already exists"
    echo "Use 'ralph init --force' to reinitialize"
    exit 0
  fi

  # Create directory structure
  info "Initializing ralph in $(basename "$(pwd)")..."

  mkdir -p ralph/loops
  mkdir -p ralph/archive
  success "Created directory structure"

  # Create config.yaml with defaults
  create_config_yaml
  success "Created ralph/config.yaml"

  echo ""
  success "Ralph initialized successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Review ralph/config.yaml and adjust defaults if needed"
  echo "  2. Create a loop: ralph create <loop-name>"
  echo "  3. Run the loop: ralph run <loop-name>"
}

# Check if current directory is a BMAD project
is_bmad_project() {
  [[ -f "docs/sprint-status.yaml" ]] || [[ -f "bmad/config.yaml" ]]
}

# Create config.yaml with defaults
create_config_yaml() {
  local project_name
  project_name="$(basename "$(pwd)")"

  # Detect BMAD paths
  local sprint_status_path="docs/sprint-status.yaml"
  local bmad_config_path="bmad/config.yaml"

  [[ ! -f "$sprint_status_path" ]] && sprint_status_path=""
  [[ ! -f "$bmad_config_path" ]] && bmad_config_path=""

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
