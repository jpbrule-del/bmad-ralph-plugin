#!/usr/bin/env bash
# ralph status - Show loop status

cmd_status() {
  local loop_name=""
  local once=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --once)
        once=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph status <loop-name> [--once]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph status <loop-name> [--once]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph status <loop-name> [--once]"
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
  local loop_path=""
  local is_archived=false

  # Check if loop exists in active loops
  if [[ -d "$loops_dir/$loop_name" ]]; then
    loop_path="$loops_dir/$loop_name"
  # Check if it's in archive (with or without date prefix)
  elif [[ -d "$archive_dir/$loop_name" ]]; then
    loop_path="$archive_dir/$loop_name"
    is_archived=true
  else
    # Try to find with date prefix
    local archived_path=$(find "$archive_dir" -maxdepth 1 -type d -name "*-$loop_name" 2>/dev/null | head -1)
    if [[ -n "$archived_path" ]]; then
      loop_path="$archived_path"
      is_archived=true
    else
      error "Loop '$loop_name' does not exist"
      echo "Run 'ralph list' to see available loops"
      exit 1
    fi
  fi

  local prd_file="$loop_path/prd.json"
  if [[ ! -f "$prd_file" ]]; then
    error "Loop configuration file not found: $prd_file"
    exit 1
  fi

  # If --once, just display once and exit
  if [[ "$once" == "true" ]]; then
    display_status "$loop_path" "$prd_file" "$is_archived"
  else
    # Real-time watch mode
    # Set up trap to handle Ctrl+C gracefully
    trap 'echo ""; info "Exiting status monitor"; exit 0' INT TERM

    info "Monitoring loop: $loop_name (Press Ctrl+C to exit)"
    echo ""

    while true; do
      clear
      display_status "$loop_path" "$prd_file" "$is_archived"
      echo ""
      echo -e "${COLOR_DIM}Refreshing every 2 seconds... (Press Ctrl+C to exit)${COLOR_RESET}"
      sleep 2
    done
  fi
}

# Display status for a loop
display_status() {
  local loop_path="$1"
  local prd_file="$2"
  local is_archived="$3"

  # Extract data from prd.json
  local project=$(jq -r '.project // "Unknown"' "$prd_file")
  local branch=$(jq -r '.branchName // "Unknown"' "$prd_file")
  local sprint_status_path=$(jq -r '.sprintStatusPath // "docs/sprint-status.yaml"' "$prd_file")

  # Configuration
  local max_iterations=$(jq -r '.config.maxIterations // 50' "$prd_file")
  local stuck_threshold=$(jq -r '.config.stuckThreshold // 3' "$prd_file")

  # Quality gates
  local typecheck=$(jq -r '.config.qualityGates.typecheck // null' "$prd_file")
  local test=$(jq -r '.config.qualityGates.test // null' "$prd_file")
  local lint=$(jq -r '.config.qualityGates.lint // null' "$prd_file")
  local build=$(jq -r '.config.qualityGates.build // null' "$prd_file")

  # Statistics
  local iterations_run=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
  local stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")
  local avg_iterations=$(jq -r '.stats.averageIterationsPerStory // 0' "$prd_file")

  # Story attempts
  local total_stories=$(jq -r '.storyAttempts | length' "$prd_file")

  # Check if loop is currently running
  local lock_file="$loop_path/.lock"
  local is_running=false
  local running_pid=""

  if [[ -f "$lock_file" ]]; then
    running_pid=$(cat "$lock_file" 2>/dev/null)
    if [[ -n "$running_pid" ]] && kill -0 "$running_pid" 2>/dev/null; then
      is_running=true
    fi
  fi

  # Get current story from progress.txt (last iteration log)
  local progress_file="$loop_path/progress.txt"
  local current_story=""
  local current_story_title=""
  local current_iteration=""

  if [[ -f "$progress_file" ]]; then
    # Try to find the last "Iteration N - STORY-XXX" line
    local last_iteration_line=$(grep -E "^## Iteration [0-9]+ - STORY-" "$progress_file" | tail -1)
    if [[ -n "$last_iteration_line" ]]; then
      current_iteration=$(echo "$last_iteration_line" | sed -E 's/^## Iteration ([0-9]+).*/\1/')
      current_story=$(echo "$last_iteration_line" | sed -E 's/^## Iteration [0-9]+ - (STORY-[0-9A-Z]+).*/\1/')
    fi
  fi

  # Get story title and epic info from sprint-status.yaml if we have a current story
  local current_epic_id=""
  local current_epic_name=""
  local epic_total_points=0
  local epic_completed_points=0

  if [[ -n "$current_story" ]] && [[ -f "$sprint_status_path" ]]; then
    current_story_title=$(yq eval ".epics[].stories[] | select(.id == \"$current_story\") | .title" "$sprint_status_path" 2>/dev/null | head -1)

    # Get epic info for current story
    current_epic_id=$(yq eval ".epics[] | select(.stories[].id == \"$current_story\") | .id" "$sprint_status_path" 2>/dev/null | head -1)

    if [[ -n "$current_epic_id" ]]; then
      current_epic_name=$(yq eval ".epics[] | select(.id == \"$current_epic_id\") | .name" "$sprint_status_path" 2>/dev/null)
      epic_total_points=$(yq eval ".epics[] | select(.id == \"$current_epic_id\") | .total_points" "$sprint_status_path" 2>/dev/null)
      epic_completed_points=$(yq eval ".epics[] | select(.id == \"$current_epic_id\") | .completed_points" "$sprint_status_path" 2>/dev/null)
    fi
  fi

  # Calculate progress percentage
  local progress_percent=0
  if [[ $total_stories -gt 0 ]]; then
    progress_percent=$((stories_completed * 100 / total_stories))
  fi

  # Calculate iterations remaining
  local iterations_remaining=$((max_iterations - iterations_run))

  # Determine iteration progress color
  local iteration_color="$COLOR_GREEN"
  local iteration_percent=0
  if [[ $max_iterations -gt 0 ]]; then
    iteration_percent=$((iterations_run * 100 / max_iterations))
    if [[ $iteration_percent -ge 80 ]]; then
      iteration_color="$COLOR_RED"
    elif [[ $iteration_percent -ge 60 ]]; then
      iteration_color="$COLOR_YELLOW"
    fi
  fi

  # Header
  header "Ralph Status Monitor"
  echo ""

  # Loop Status
  section "Loop Status"
  echo "Loop Name:      $(basename "$loop_path")"
  echo "Project:        $project"
  echo "Branch:         $branch"

  # Status indicator
  if [[ "$is_archived" == "true" ]]; then
    echo "State:          ${COLOR_YELLOW}Archived${COLOR_RESET}"
  elif [[ "$is_running" == "true" ]]; then
    echo "State:          ${COLOR_GREEN}● Running${COLOR_RESET} (PID: $running_pid)"
  else
    echo "State:          ${COLOR_DIM}○ Idle${COLOR_RESET}"
  fi
  echo ""

  # Current Story
  section "Current Story"
  if [[ -n "$current_story" ]]; then
    echo "Story ID:       $current_story"
    if [[ -n "$current_story_title" ]]; then
      echo "Title:          $current_story_title"
    fi

    # Get attempt count for current story
    local current_attempts=$(jq -r ".storyAttempts.\"$current_story\" // 0" "$prd_file")

    if [[ $current_attempts -ge $stuck_threshold ]]; then
      echo "Attempts:       ${COLOR_RED}$current_attempts / $stuck_threshold (STUCK!)${COLOR_RESET}"
    elif [[ $current_attempts -ge $((stuck_threshold - 1)) ]]; then
      echo "Attempts:       ${COLOR_YELLOW}$current_attempts / $stuck_threshold (approaching threshold)${COLOR_RESET}"
    else
      echo "Attempts:       $current_attempts / $stuck_threshold"
    fi
  else
    echo "${COLOR_DIM}No story currently in progress${COLOR_RESET}"
  fi
  echo ""

  # Progress
  section "Progress"
  echo "Stories:        $stories_completed / $total_stories completed ($progress_percent%)"

  # Overall progress bar
  local bar_width=40
  local filled=$((progress_percent * bar_width / 100))
  local empty=$((bar_width - filled))
  echo -n "Overall:        ["
  for ((i=0; i<filled; i++)); do echo -n "█"; done
  for ((i=0; i<empty; i++)); do echo -n "░"; done
  echo "]"

  # Current epic progress bar (if we have epic info)
  if [[ -n "$current_epic_id" ]] && [[ $epic_total_points -gt 0 ]]; then
    local epic_progress_percent=$((epic_completed_points * 100 / epic_total_points))
    local epic_filled=$((epic_progress_percent * bar_width / 100))
    local epic_empty=$((bar_width - epic_filled))

    echo ""
    echo "Epic:           $current_epic_name ($current_epic_id)"
    echo "Points:         $epic_completed_points / $epic_total_points points ($epic_progress_percent%)"
    echo -n "Epic Progress:  ["
    for ((i=0; i<epic_filled; i++)); do echo -n "█"; done
    for ((i=0; i<epic_empty; i++)); do echo -n "░"; done
    echo "]"
  fi

  echo ""
  echo -e "Iterations:     ${iteration_color}$iterations_run / $max_iterations${COLOR_RESET} ($iterations_remaining remaining)"

  if [[ "$avg_iterations" != "0" ]] && [[ "$avg_iterations" != "null" ]]; then
    echo "Avg/Story:      $avg_iterations iterations"
  fi
  echo ""

  # Quality Gates
  section "Quality Gates"
  local gates_enabled=0

  if [[ "$typecheck" != "null" ]]; then
    echo "${COLOR_GREEN}✓${COLOR_RESET} Typecheck:  $typecheck"
    ((gates_enabled++))
  else
    echo "${COLOR_DIM}○ Typecheck:  (disabled)${COLOR_RESET}"
  fi

  if [[ "$test" != "null" ]]; then
    echo "${COLOR_GREEN}✓${COLOR_RESET} Test:       $test"
    ((gates_enabled++))
  else
    echo "${COLOR_DIM}○ Test:       (disabled)${COLOR_RESET}"
  fi

  if [[ "$lint" != "null" ]]; then
    echo "${COLOR_GREEN}✓${COLOR_RESET} Lint:       $lint"
    ((gates_enabled++))
  else
    echo "${COLOR_DIM}○ Lint:       (disabled)${COLOR_RESET}"
  fi

  if [[ "$build" != "null" ]]; then
    echo "${COLOR_GREEN}✓${COLOR_RESET} Build:      $build"
    ((gates_enabled++))
  else
    echo "${COLOR_DIM}○ Build:      (disabled)${COLOR_RESET}"
  fi

  if [[ $gates_enabled -eq 0 ]]; then
    echo ""
    warn "No quality gates enabled"
  fi
  echo ""

  # Recent Activity
  section "Recent Activity"
  if [[ -f "$progress_file" ]]; then
    # Show last 5 lines (excluding empty lines)
    tail -20 "$progress_file" | grep -v "^$" | tail -5
  else
    echo "${COLOR_DIM}No activity log found${COLOR_RESET}"
  fi
}
