#!/usr/bin/env bash
# ralph create - Create a new loop

# Source sprint analysis and generator utilities
# Use the LIB_DIR variable from main script, or fallback to relative path
readonly CREATE_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
source "$CREATE_LIB_DIR/core/sprint_analysis.sh"
source "$CREATE_LIB_DIR/core/git.sh"
source "$CREATE_LIB_DIR/core/interactive.sh"
source "$CREATE_LIB_DIR/generator/loop_generator.sh"
source "$CREATE_LIB_DIR/generator/prd_generator.sh"
source "$CREATE_LIB_DIR/generator/prompt_generator.sh"
source "$CREATE_LIB_DIR/generator/progress_generator.sh"

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

  # Interactive configuration (unless --yes flag is set)
  local max_iterations=50
  local stuck_threshold=3
  local quality_gates_json

  if [[ "$yes_mode" == true ]]; then
    # Use defaults when --yes flag is provided
    info "Using default configuration (--yes flag)"

    # Get default quality gates from ralph config
    quality_gates_json=$(get_default_quality_gates)

    # Epic filter already set from --epic flag or empty
  else
    # Interactive prompts
    header "Loop Configuration"

    # Prompt for epic filter if not already specified
    if [[ -z "$epic_filter" ]]; then
      epic_filter=$(prompt_epic_filter "$epic_filter")
    fi

    # Prompt for max iterations
    max_iterations=$(prompt_max_iterations 50)

    # Prompt for stuck threshold
    stuck_threshold=$(prompt_stuck_threshold 3)

    # Prompt for quality gates
    quality_gates_json=$(prompt_quality_gates)

    # Display configuration summary
    display_config_summary "$epic_filter" "$max_iterations" "$stuck_threshold" "$quality_gates_json"

    # Confirm configuration
    echo ""
    read -rp "Create loop with this configuration? [Y/n]: " confirm
    confirm="${confirm:-Y}"

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      warning "Loop creation cancelled"
      exit 0
    fi
  fi

  # Update ralph config with quality gates (if not using defaults)
  if [[ "$yes_mode" == false ]]; then
    # Update quality gates in ralph/config.json (or config.yaml if it exists)
    if [[ -f "ralph/config.json" ]]; then
      info "Updating quality gates configuration..."

      # Parse quality gates from collected JSON
      local typecheck test lint build
      typecheck=$(echo "$quality_gates_json" | jq -r '.typecheck')
      test=$(echo "$quality_gates_json" | jq -r '.test')
      lint=$(echo "$quality_gates_json" | jq -r '.lint')
      build=$(echo "$quality_gates_json" | jq -r '.build')

      # Update config using jq (atomic write pattern)
      local temp_file
      temp_file=$(mktemp)

      jq --arg typecheck "$typecheck" \
         --arg test "$test" \
         --arg lint "$lint" \
         --arg build "$build" \
         '.config.qualityGates.typecheck = (if $typecheck == "null" then null else $typecheck end) |
          .config.qualityGates.test = (if $test == "null" then null else $test end) |
          .config.qualityGates.lint = (if $lint == "null" then null else $lint end) |
          .config.qualityGates.build = (if $build == "null" then null else $build end)' \
         ralph/config.json > "$temp_file"

      if jq . "$temp_file" >/dev/null 2>&1; then
        mv "$temp_file" ralph/config.json
        success "Updated quality gates configuration"
      else
        rm -f "$temp_file"
        warning "Failed to update quality gates, using existing configuration"
      fi
    fi
  fi

  echo ""

  # Create loop directory
  info "Creating loop: $loop_name"
  mkdir -p "$loop_dir"
  success "Created loop directory: $loop_dir"

  # Generate loop.sh
  info "Generating loop.sh orchestration script..."
  if generate_loop_sh "$loop_name" "$loop_dir" "$epic_filter" "$max_iterations" "$stuck_threshold"; then
    success "Generated loop.sh"
  else
    error "Failed to generate loop.sh"
    exit 1
  fi

  # Generate config.json
  info "Generating config.json configuration file..."
  if generate_prd_json "$loop_name" "$loop_dir" "$epic_filter" "$max_iterations" "$stuck_threshold"; then
    success "Generated config.json"
  else
    error "Failed to generate config.json"
    exit 1
  fi

  # Generate prompt.md
  info "Generating prompt.md context file..."
  if generate_prompt_md "$loop_name" "$loop_dir" "$epic_filter"; then
    success "Generated prompt.md"
  else
    error "Failed to generate prompt.md"
    exit 1
  fi

  # Generate progress.txt
  info "Generating progress.txt iteration log file..."
  if generate_progress_txt "$loop_name" "$loop_dir"; then
    success "Generated progress.txt"
  else
    error "Failed to generate progress.txt"
    exit 1
  fi

  # Create git branch unless --no-branch flag was provided
  if [[ "$no_branch" == false ]]; then
    echo ""
    info "Creating git branch..."
    if create_loop_branch "$loop_name"; then
      # Branch creation succeeded or user is already on the branch
      :
    else
      # Branch creation failed or was cancelled
      warning "Continuing without branch creation"
      echo ""
      echo "You can manually create a branch later with:"
      echo "  git checkout -b ralph/$loop_name"
    fi
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
