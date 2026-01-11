#!/usr/bin/env bash
# ralph create - Create a new loop

cmd_create() {
  local loop_name=""
  local epic_filter=""
  local yes_mode=false
  local no_branch=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --epic)
        if [[ -z "${2:-}" ]]; then
          error "Option --epic requires an argument"
          echo "Usage: ralph create <loop-name> [--epic <id>] [--yes] [--no-branch]"
          exit 1
        fi
        epic_filter="$2"
        shift 2
        ;;
      --yes)
        yes_mode=true
        shift
        ;;
      --no-branch)
        no_branch=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph create <loop-name> [--epic <id>] [--yes] [--no-branch]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph create <loop-name> [--epic <id>] [--yes] [--no-branch]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Require loop name
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph create <loop-name> [--epic <id>] [--yes] [--no-branch]"
    exit 1
  fi

  # Validate loop name (alphanumeric + hyphens)
  if ! validate_loop_name "$loop_name"; then
    error "Invalid loop name: $loop_name"
    echo ""
    echo "Loop name must:"
    echo "  • Contain only alphanumeric characters and hyphens"
    echo "  • Start with a letter or number"
    echo "  • Not end with a hyphen"
    echo ""
    echo "Valid examples: feature-auth, sprint-1, epic002"
    exit 1
  fi

  # Check if ralph is initialized
  if [[ ! -f "ralph/config.yaml" ]] && [[ ! -f "ralph/config.json" ]]; then
    error "Ralph is not initialized in this project"
    echo ""
    echo "Run 'ralph init' first to initialize ralph"
    exit 1
  fi

  # Check if loop already exists
  local loop_dir="ralph/loops/$loop_name"
  if [[ -d "$loop_dir" ]]; then
    error "Loop already exists: $loop_name"
    echo ""
    echo "Loop directory already exists at: $loop_dir"
    echo "Choose a different name or delete the existing loop first"
    exit 1
  fi

  # Create loop directory
  info "Creating loop: $loop_name"
  mkdir -p "$loop_dir"
  success "Created loop directory: $loop_dir"

  echo ""
  success "Loop '$loop_name' created successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Run the loop: ralph run $loop_name"
  echo "  2. Monitor progress: ralph status $loop_name"
}

# Validate loop name format
validate_loop_name() {
  local name="$1"

  # Must contain only alphanumeric characters and hyphens
  # Must start with alphanumeric
  # Must not end with hyphen
  if [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]] || [[ "$name" =~ ^[a-zA-Z0-9]$ ]]; then
    return 0
  else
    return 1
  fi
}
