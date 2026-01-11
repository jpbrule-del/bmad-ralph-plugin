#!/usr/bin/env bash
# ralph create - Create a new loop

# Source sprint analysis and generator utilities
# Use the LIB_DIR variable from main script, or fallback to relative path
readonly CREATE_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
source "$CREATE_LIB_DIR/core/sprint_analysis.sh"
source "$CREATE_LIB_DIR/generator/loop_generator.sh"
source "$CREATE_LIB_DIR/generator/prd_generator.sh"

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

  # Validate sprint-status.yaml exists and is readable
  info "Analyzing sprint status..."
  if ! validate_sprint_status; then
    exit 1
  fi

  # Validate epic filter if provided
  if [[ -n "$epic_filter" ]]; then
    if ! epic_exists "$epic_filter"; then
      error "Epic not found: $epic_filter"
      echo ""
      echo "Available epics:"
      while IFS= read -r epic_id; do
        local epic_name
        epic_name=$(get_epic_name "$epic_id")
        echo "  $epic_id: $epic_name"
      done < <(get_all_epics)
      exit 1
    fi
  fi

  # Get pending stories count
  local story_count
  story_count=$(get_pending_story_count "$epic_filter")

  if [[ "$story_count" -eq 0 ]]; then
    warning "No pending stories found"
    if [[ -n "$epic_filter" ]]; then
      echo ""
      echo "Epic $epic_filter has no pending stories"
      echo "All stories may already be completed"
    else
      echo ""
      echo "All stories in sprint may already be completed"
    fi
    exit 1
  fi

  # Display story analysis
  echo ""
  if [[ -n "$epic_filter" ]]; then
    local epic_name
    epic_name=$(get_epic_name "$epic_filter")
    header "Epic: $epic_filter - $epic_name"
  else
    header "All Epics"
  fi

  echo ""
  info "Found $story_count pending stories"
  echo ""

  # Show first few stories as preview
  local preview_count=0
  local max_preview=5

  while IFS= read -r story_yaml; do
    if [[ $preview_count -lt $max_preview ]]; then
      print_story_summary "$story_yaml"
      ((preview_count++))
    fi
  done < <(get_pending_stories "$epic_filter")

  if [[ $story_count -gt $max_preview ]]; then
    echo "  ... and $((story_count - max_preview)) more"
  fi

  echo ""

  # Create loop directory
  info "Creating loop: $loop_name"
  mkdir -p "$loop_dir"
  success "Created loop directory: $loop_dir"

  # Generate loop.sh
  info "Generating loop.sh orchestration script..."
  if generate_loop_sh "$loop_name" "$loop_dir" "$epic_filter"; then
    success "Generated loop.sh"
  else
    error "Failed to generate loop.sh"
    exit 1
  fi

  # Generate prd.json
  info "Generating prd.json configuration file..."
  if generate_prd_json "$loop_name" "$loop_dir" "$epic_filter"; then
    success "Generated prd.json"
  else
    error "Failed to generate prd.json"
    exit 1
  fi

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
