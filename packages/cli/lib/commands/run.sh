#!/usr/bin/env bash
# ralph run - Run a loop (v2: BMAD-native)

# Source required modules
source "$LIB_DIR/core/git.sh"
source "$LIB_DIR/core/bmad_config.sh"
source "$LIB_DIR/core/migration.sh"

cmd_run() {
  # Check for migration (v1 -> v2)
  check_and_migrate

  local loop_name=""
  local dry_run=false
  local restart=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      --restart)
        restart=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph run <loop-name> [--dry-run] [--restart]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph run <loop-name> [--dry-run] [--restart]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph run <loop-name> [--dry-run] [--restart]"
    exit 1
  fi

  # Ensure ralph is initialized
  if [[ ! -d "ralph" ]]; then
    error "Ralph is not initialized in this project"
    echo "Run 'ralph init' to initialize"
    exit 1
  fi

  local loops_dir="ralph/loops"
  local archive_dir="ralph/archive"
  local loop_path="$loops_dir/$loop_name"

  # Check if loop exists in active loops
  if [[ ! -d "$loop_path" ]]; then
    # Check if it's in archive
    if [[ -d "$archive_dir/$loop_name" ]] || compgen -G "$archive_dir/*-$loop_name" >/dev/null 2>&1; then
      error "Cannot run archived loops"
      echo "Loop '$loop_name' is archived"
      echo "Use 'ralph unarchive $loop_name' first to restore it"
      exit 1
    fi

    error "Loop '$loop_name' does not exist"
    echo "Run 'ralph list' to see available loops"
    exit 1
  fi

  # Validate loop state file exists (v2: .state.json or v1: config.json)
  local state_file="$loop_path/.state.json"
  local config_file="$loop_path/config.json"  # v1 legacy
  local prd_file=""

  if [[ -f "$state_file" ]]; then
    # v2: Use .state.json
    prd_file="$state_file"
  elif [[ -f "$config_file" ]]; then
    # v1 legacy: Use config.json
    prd_file="$config_file"
  else
    error "Invalid loop: no state file found (.state.json or config.json)"
    exit 1
  fi

  # Get branch name from sprint-status.yaml (v2) or config.json (v1)
  local branch_name=""

  # Try to get branch from sprint-status.yaml ralph_loops section (v2)
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)
  if [[ -n "$sprint_file" ]] && [[ -f "$sprint_file" ]]; then
    branch_name=$(yq eval ".ralph_loops[] | select(.name == \"$loop_name\") | .branch" "$sprint_file" 2>/dev/null)
  fi

  # Fall back to config.json if not found (v1 or missing)
  if [[ -z "$branch_name" ]] || [[ "$branch_name" == "null" ]]; then
    if [[ -f "$config_file" ]]; then
      branch_name=$(jq -r '.branchName // ""' "$config_file")
    fi
  fi

  # Default to convention-based branch name
  if [[ -z "$branch_name" ]] || [[ "$branch_name" == "null" ]]; then
    branch_name="ralph/$loop_name"
  fi

  # Check for existing lock file
  local lock_file="$loop_path/.lock"
  if [[ -f "$lock_file" ]]; then
    local lock_pid
    lock_pid=$(cat "$lock_file" 2>/dev/null)

    # Check if the process is still running
    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
      error "Loop is already running (PID: $lock_pid)"
      echo "If you believe this is an error, remove the lock file:"
      echo "  rm \"$lock_file\""
      exit 1
    else
      # Stale lock file - remove it
      warning "Removing stale lock file"
      rm -f "$lock_file"
    fi
  fi

  # Create lock file with current PID
  echo $$ > "$lock_file"

  # Set up trap to remove lock file on exit
  trap "rm -f '$lock_file'" EXIT INT TERM

  # Checkout the associated git branch
  local current_branch
  current_branch=$(get_current_branch)

  if [[ "$current_branch" != "$branch_name" ]]; then
    info "Checking out branch: $branch_name"

    # Check if branch exists
    if ! branch_exists "$branch_name"; then
      error "Branch does not exist: $branch_name"
      echo "The loop configuration references a branch that doesn't exist."
      echo "You may need to create it manually:"
      echo "  git checkout -b $branch_name"
      exit 1
    fi

    # Checkout the branch
    if ! git checkout "$branch_name" 2>/dev/null; then
      error "Failed to checkout branch: $branch_name"
      echo "Ensure there are no uncommitted changes or conflicts"
      exit 1
    fi

    success "Checked out branch: $branch_name"
  else
    info "Already on branch: $branch_name"
  fi

  # Execute the loop
  success "Loop validation passed"
  info "Starting loop execution: $loop_name"
  echo ""

  # Build loop.sh arguments
  local loop_args=()
  if [[ "$restart" == "true" ]]; then
    loop_args+=(--restart)
  fi

  # Execute loop.sh script
  local loop_script="$loop_path/loop.sh"
  if [[ ! -f "$loop_script" ]]; then
    error "Loop script not found: $loop_script"
    echo "The loop may be corrupted. Try recreating it."
    exit 1
  fi

  # Make loop.sh executable if it isn't already
  chmod +x "$loop_script"

  # Execute the loop script
  # Pass through exit code from loop.sh
  if [[ "$dry_run" == "true" ]]; then
    # Dry run mode - show what would be executed without actually running
    perform_dry_run "$loop_path" "$prd_file"
  else
    # Execute the loop (use safe array expansion for empty arrays with set -u)
    exec "$loop_script" ${loop_args[@]+"${loop_args[@]}"}
  fi
}

# Perform dry run - show what would be executed without running
perform_dry_run() {
  local loop_path="$1"
  local prd_file="$2"
  local loop_name=$(basename "$loop_path")

  # Colors for output
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local BOLD='\033[1m'
  local DIM='\033[2m'
  local NC='\033[0m'

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC} ${BOLD}DRY RUN MODE${NC} - Simulation (no files will be modified)"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Determine config source (v2: bmad/config.yaml, v1: config.json)
  local is_v2=false
  local project_name=""
  local branch_name=""
  local sprint_status_path=""
  local max_iterations=50
  local stuck_threshold=3
  local typecheck_cmd="disabled"
  local test_cmd="disabled"
  local lint_cmd="disabled"
  local build_cmd="disabled"

  if [[ -f "bmad/config.yaml" ]] && yq eval '.ralph // ""' bmad/config.yaml 2>/dev/null | grep -q "version"; then
    is_v2=true
    # v2: Read from bmad/config.yaml and sprint-status.yaml
    project_name=$(get_bmad_project_name)
    sprint_status_path=$(get_bmad_sprint_status_path || echo "docs/sprint-status.yaml")

    # Get branch from sprint-status.yaml ralph_loops section
    if [[ -f "$sprint_status_path" ]]; then
      branch_name=$(yq eval ".ralph_loops[] | select(.name == \"$loop_name\") | .branch" "$sprint_status_path" 2>/dev/null)
    fi
    # Fallback to convention-based branch name
    if [[ -z "$branch_name" ]] || [[ "$branch_name" == "null" ]]; then
      branch_name="ralph/$loop_name"
    fi

    # Read configuration from bmad/config.yaml ralph section
    max_iterations=$(get_ralph_max_iterations)
    stuck_threshold=$(get_ralph_stuck_threshold)

    # Quality gates from bmad/config.yaml
    typecheck_cmd=$(yq -r '.ralph.defaults.quality_gates.typecheck // "disabled"' bmad/config.yaml 2>/dev/null)
    test_cmd=$(yq -r '.ralph.defaults.quality_gates.test // "disabled"' bmad/config.yaml 2>/dev/null)
    lint_cmd=$(yq -r '.ralph.defaults.quality_gates.lint // "disabled"' bmad/config.yaml 2>/dev/null)
    build_cmd=$(yq -r '.ralph.defaults.quality_gates.build // "disabled"' bmad/config.yaml 2>/dev/null)

    # Handle empty strings and null as disabled
    [[ -z "$typecheck_cmd" || "$typecheck_cmd" == "null" ]] && typecheck_cmd="disabled"
    [[ -z "$test_cmd" || "$test_cmd" == "null" ]] && test_cmd="disabled"
    [[ -z "$lint_cmd" || "$lint_cmd" == "null" ]] && lint_cmd="disabled"
    [[ -z "$build_cmd" || "$build_cmd" == "null" ]] && build_cmd="disabled"
  else
    # v1: Read from config.json
    project_name=$(jq -r '.project // "Unknown"' "$prd_file")
    branch_name=$(jq -r '.branchName // "Unknown"' "$prd_file")
    sprint_status_path=$(jq -r '.sprintStatusPath // "docs/sprint-status.yaml"' "$prd_file")
    max_iterations=$(jq -r '.config.maxIterations // 50' "$prd_file")
    stuck_threshold=$(jq -r '.config.stuckThreshold // 3' "$prd_file")

    typecheck_cmd=$(jq -r '.config.qualityGates.typecheck // "disabled"' "$prd_file")
    test_cmd=$(jq -r '.config.qualityGates.test // "disabled"' "$prd_file")
    lint_cmd=$(jq -r '.config.qualityGates.lint // "disabled"' "$prd_file")
    build_cmd=$(jq -r '.config.qualityGates.build // "disabled"' "$prd_file")
  fi

  # 1. Validate and display configuration
  echo -e "${BOLD}Configuration Validation:${NC}"
  local validation_passed=true

  if [[ "$is_v2" == "true" ]]; then
    # v2 validation: Check bmad/config.yaml ralph section
    echo -e "  ${GREEN}✓${NC}  bmad/config.yaml (ralph section)"
    echo -e "  ${GREEN}✓${NC}  project: $project_name"
    echo -e "  ${GREEN}✓${NC}  branch: $branch_name"
    echo -e "  ${GREEN}✓${NC}  max_iterations: $max_iterations"
    echo -e "  ${GREEN}✓${NC}  stuck_threshold: $stuck_threshold"
  else
    # v1 validation: Check config.json fields
    local required_fields=("project" "branchName" "sprintStatusPath" "config.maxIterations" "config.stuckThreshold" "config.qualityGates")

    for field in "${required_fields[@]}"; do
      local value
      value=$(jq -r ".$field // empty" "$prd_file" 2>/dev/null)
      if [[ -z "$value" || "$value" == "null" ]]; then
        echo -e "  ${YELLOW}⚠${NC}  Missing or invalid: $field"
        validation_passed=false
      else
        echo -e "  ${GREEN}✓${NC}  $field"
      fi
    done
  fi

  # Validate required files exist
  local prompt_file="$loop_path/prompt.md"
  local progress_file="$loop_path/progress.txt"
  local loop_script="$loop_path/loop.sh"

  for file in "$prompt_file" "$progress_file" "$loop_script"; do
    if [[ -f "$file" ]]; then
      echo -e "  ${GREEN}✓${NC}  $(basename "$file") exists"
    else
      echo -e "  ${YELLOW}⚠${NC}  Missing file: $(basename "$file")"
      validation_passed=false
    fi
  done

  # Validate sprint status file
  if [[ -f "$sprint_status_path" ]]; then
    echo -e "  ${GREEN}✓${NC}  Sprint status file: $sprint_status_path"
  else
    echo -e "  ${YELLOW}⚠${NC}  Sprint status file not found: $sprint_status_path"
    validation_passed=false
  fi

  if [[ "$validation_passed" == "false" ]]; then
    echo ""
    echo -e "${YELLOW}Configuration has validation warnings${NC}"
  else
    echo ""
    echo -e "${GREEN}✓ Configuration is valid${NC}"
  fi

  # 2. Display loop configuration
  echo ""
  echo -e "${BOLD}Loop Configuration:${NC}"

  echo -e "  ${DIM}Project:${NC}           $project_name"
  echo -e "  ${DIM}Branch:${NC}            $branch_name"
  echo -e "  ${DIM}Max Iterations:${NC}    $max_iterations"
  echo -e "  ${DIM}Stuck Threshold:${NC}   $stuck_threshold"

  # Display quality gates
  echo ""
  echo -e "${BOLD}Quality Gates:${NC}"

  [[ "$typecheck_cmd" != "null" && "$typecheck_cmd" != "disabled" ]] && echo -e "  ${GREEN}✓${NC}  Typecheck: $typecheck_cmd" || echo -e "  ${DIM}○${NC}  Typecheck: disabled"
  [[ "$test_cmd" != "null" && "$test_cmd" != "disabled" ]] && echo -e "  ${GREEN}✓${NC}  Test: $test_cmd" || echo -e "  ${DIM}○${NC}  Test: disabled"
  [[ "$lint_cmd" != "null" && "$lint_cmd" != "disabled" ]] && echo -e "  ${GREEN}✓${NC}  Lint: $lint_cmd" || echo -e "  ${DIM}○${NC}  Lint: disabled"
  [[ "$build_cmd" != "null" && "$build_cmd" != "disabled" ]] && echo -e "  ${GREEN}✓${NC}  Build: $build_cmd" || echo -e "  ${DIM}○${NC}  Build: disabled"

  # 3. Display stories that would be processed
  echo ""
  echo -e "${BOLD}Stories to Process:${NC}"

  if [[ ! -f "$sprint_status_path" ]]; then
    echo -e "  ${YELLOW}⚠${NC}  Cannot read sprint status file"
  else
    # Extract pending stories (not completed - support both hyphen and underscore status values)
    local pending_stories
    pending_stories=$(yq eval -o json '[.epics[].stories[] | select(.status == "not_started" or .status == "not-started" or .status == "in_progress" or .status == "in-progress")]' "$sprint_status_path" 2>/dev/null | jq '[.[] | {id: .id, title: .title, status: .status, points: .points}]')

    local story_count
    story_count=$(echo "$pending_stories" | jq 'length')

    if [[ "$story_count" -eq 0 ]]; then
      echo -e "  ${GREEN}✓${NC}  No pending stories found - all work is complete!"
    else
      echo -e "  ${BLUE}${story_count}${NC} pending stories would be processed:"
      echo ""

      # Display stories
      local i=0
      while [[ $i -lt $story_count ]]; do
        local story_id
        local story_title
        local story_status
        local story_points

        story_id=$(echo "$pending_stories" | jq -r ".[$i].id")
        story_title=$(echo "$pending_stories" | jq -r ".[$i].title")
        story_status=$(echo "$pending_stories" | jq -r ".[$i].status")
        story_points=$(echo "$pending_stories" | jq -r ".[$i].points")

        # Color code by status (support both hyphen and underscore)
        local status_indicator
        if [[ "$story_status" == "in-progress" || "$story_status" == "in_progress" ]]; then
          status_indicator="${YELLOW}●${NC}"
        else
          status_indicator="${DIM}○${NC}"
        fi

        echo -e "  $status_indicator  ${BLUE}$story_id${NC} ($story_points pts) - $story_title"

        # Only show first 10 stories, then summarize
        if [[ $i -eq 9 && $story_count -gt 10 ]]; then
          local remaining=$((story_count - 10))
          echo -e "  ${DIM}   ... and $remaining more stories${NC}"
          break
        fi

        i=$((i + 1))
      done

      # Calculate total points
      local total_points
      total_points=$(echo "$pending_stories" | jq '[.[].points] | add')
      echo ""
      echo -e "  ${DIM}Total points remaining:${NC} $total_points"
    fi
  fi

  # 4. Display execution statistics if available
  local iterations_run
  local stories_completed
  local avg_iterations

  iterations_run=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
  stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")
  avg_iterations=$(jq -r '.stats.averageIterationsPerStory // 0' "$prd_file")

  if [[ "$iterations_run" -gt 0 ]]; then
    echo ""
    echo -e "${BOLD}Current Progress:${NC}"
    echo -e "  ${DIM}Iterations run:${NC}      $iterations_run"
    echo -e "  ${DIM}Stories completed:${NC}   $stories_completed"
    echo -e "  ${DIM}Avg iterations/story:${NC} $avg_iterations"
  fi

  # 5. Summary
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC} ${BOLD}Dry Run Complete${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${DIM}To actually execute this loop, run:${NC}"
  echo -e "  ${GREEN}ralph run $(basename "$loop_path")${NC}"
  echo ""

  exit 0
}
