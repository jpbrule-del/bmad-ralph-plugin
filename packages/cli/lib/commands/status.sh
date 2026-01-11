#!/usr/bin/env bash
# ralph status - Show loop status (v2: BMAD-native)

# Source required modules
source "$LIB_DIR/core/bmad_config.sh"
source "$LIB_DIR/core/migration.sh"

cmd_status() {
  # Check for migration (v1 -> v2)
  check_and_migrate
  local loop_name=""
  local once=false
  local refresh_rate=2

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --once)
        once=true
        shift
        ;;
      --refresh)
        if [[ -z "$2" ]] || [[ "$2" =~ ^- ]]; then
          error "--refresh requires a numeric argument (seconds)"
          echo "Usage: ralph status <loop-name> [--once] [--refresh <seconds>]"
          exit 1
        fi
        # Validate numeric
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          error "Refresh rate must be a positive integer"
          echo "Usage: ralph status <loop-name> [--once] [--refresh <seconds>]"
          exit 1
        fi
        refresh_rate="$2"
        shift 2
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph status <loop-name> [--once] [--refresh <seconds>]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph status <loop-name> [--once] [--refresh <seconds>]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph status <loop-name> [--once] [--refresh <seconds>]"
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

  # Validate loop state file exists (v2: .state.json or v1: config.json)
  local state_file="$loop_path/.state.json"
  local config_file="$loop_path/config.json"  # v1 legacy
  local prd_file=""

  if [[ -f "$state_file" ]]; then
    # v2: Use .state.json for runtime state
    prd_file="$state_file"
  elif [[ -f "$config_file" ]]; then
    # v1 legacy: Use config.json
    prd_file="$config_file"
  else
    error "Loop state file not found (.state.json or config.json)"
    exit 1
  fi

  # If --once, just display once and exit
  if [[ "$once" == "true" ]]; then
    display_status "$loop_path" "$prd_file" "$is_archived"
  else
    # Real-time watch mode
    # Set up trap to handle Ctrl+C gracefully and restore terminal
    local old_stty=""
    if [[ -t 0 ]]; then
      old_stty=$(stty -g 2>/dev/null)
    fi

    cleanup_status() {
      # Show cursor and restore terminal settings
      printf '\033[?25h'  # Show cursor
      if [[ -n "$old_stty" ]]; then
        stty "$old_stty" 2>/dev/null
      fi
      echo ""
      info "Exiting status monitor"
      exit 0
    }

    trap cleanup_status INT TERM EXIT

    info "Monitoring loop: $loop_name (Press q to quit, r to refresh)"
    echo ""

    # ANSI escape sequences for live dashboard
    local ESC=$'\033'
    local CURSOR_HOME="${ESC}[H"
    local CURSOR_HIDE="${ESC}[?25l"
    local CURSOR_SHOW="${ESC}[?25h"
    local CLEAR_SCREEN="${ESC}[2J"
    local CLEAR_LINE="${ESC}[K"

    # First display: clear screen completely
    local first_display=true

    while true; do
      # Hide cursor during update to prevent flickering
      printf '%s' "$CURSOR_HIDE"

      if [[ "$first_display" == "true" ]]; then
        # First time: clear screen and move home
        printf '%s%s' "$CLEAR_SCREEN" "$CURSOR_HOME"
        first_display=false
      else
        # Subsequent updates: just move cursor home (no flash!)
        printf '%s' "$CURSOR_HOME"
      fi

      # Display status with line clearing for clean updates
      display_status_live "$loop_path" "$prd_file" "$is_archived" "$CLEAR_LINE"

      # Footer with instructions
      printf '%s\n' "$CLEAR_LINE"
      printf '%s%s\n' "${COLOR_DIM}Refreshing every ${refresh_rate}s... (Press 'q' to quit, 'r' to refresh now, 'l' to view full log)${COLOR_RESET}" "$CLEAR_LINE"

      # Show cursor again
      printf '%s' "$CURSOR_SHOW"

      # Handle keypress with timeout
      local key=""

      # Check if we have a terminal for interactive input
      if [[ -t 0 ]]; then
        # Set terminal to raw mode for single keypress
        stty -echo -icanon min 0 time $((refresh_rate * 10)) 2>/dev/null
        key=$(dd bs=1 count=1 2>/dev/null)
        # Restore terminal
        if [[ -n "$old_stty" ]]; then
          stty "$old_stty" 2>/dev/null
        fi
      else
        # No terminal, just sleep
        sleep "$refresh_rate"
      fi

      # Handle keypresses
      case "$key" in
        q|Q)
          # Remove EXIT trap to avoid double message
          trap - EXIT
          cleanup_status
          ;;
        r|R)
          # Refresh immediately by continuing loop
          continue
          ;;
        l|L)
          # Show full log
          local progress_file="$loop_path/progress.txt"
          if [[ -f "$progress_file" ]]; then
            printf '\033[2J\033[H'  # Clear screen for log view
            echo -e "${COLOR_CYAN}════════════════════════════════════════════════════════════════${COLOR_RESET}"
            echo -e "${COLOR_CYAN}  Full Log: $loop_name${COLOR_RESET}"
            echo -e "${COLOR_CYAN}════════════════════════════════════════════════════════════════${COLOR_RESET}"
            echo ""

            # Use less if available for better navigation, otherwise cat
            if command -v less &> /dev/null; then
              less -R "$progress_file"
            else
              cat "$progress_file"
              echo ""
              echo -e "${COLOR_DIM}Press any key to continue...${COLOR_RESET}"
              read -n 1 -s -r
            fi
            # Reset first_display to clear screen when returning to dashboard
            first_display=true
          else
            echo ""
            warn "No log file found: $progress_file"
            sleep 2
          fi
          # Continue the loop to refresh display
          continue
          ;;
        *)
          # Empty or unrecognized key - just continue loop
          continue
          ;;
      esac
    done
  fi
}

# Display status for live dashboard (clears each line to prevent artifacts)
display_status_live() {
  local loop_path="$1"
  local prd_file="$2"
  local is_archived="$3"
  local clear_line="$4"

  # Capture display_status output and add clear-to-end-of-line for each line
  # This prevents screen artifacts when line lengths change
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s%s\n' "$line" "$clear_line"
  done < <(display_status "$loop_path" "$prd_file" "$is_archived")
}

# Display status for a loop
display_status() {
  local loop_path="$1"
  local prd_file="$2"
  local is_archived="$3"
  local loop_name=$(basename "$loop_path")

  # Determine config source (v2: bmad/config.yaml, v1: config.json)
  local project=""
  local branch=""
  local sprint_status_path=""
  local max_iterations=50
  local stuck_threshold=3
  local typecheck="null"
  local test="null"
  local lint="null"
  local build="null"

  if [[ -f "bmad/config.yaml" ]] && yq eval '.ralph // ""' bmad/config.yaml 2>/dev/null | grep -q "version"; then
    # v2: Read from bmad/config.yaml and sprint-status.yaml
    project=$(get_bmad_project_name)
    sprint_status_path=$(get_bmad_sprint_status_path || echo "docs/sprint-status.yaml")

    # Get branch from sprint-status.yaml ralph_loops section
    if [[ -f "$sprint_status_path" ]]; then
      branch=$(yq eval ".ralph_loops[] | select(.name == \"$loop_name\") | .branch" "$sprint_status_path" 2>/dev/null)
    fi
    # Fallback to convention-based branch name
    if [[ -z "$branch" ]] || [[ "$branch" == "null" ]]; then
      branch="ralph/$loop_name"
    fi

    # Read configuration from bmad/config.yaml ralph section
    max_iterations=$(get_ralph_max_iterations)
    stuck_threshold=$(get_ralph_stuck_threshold)

    # Quality gates from bmad/config.yaml
    typecheck=$(yq -r '.ralph.defaults.quality_gates.typecheck // "null"' bmad/config.yaml 2>/dev/null)
    test=$(yq -r '.ralph.defaults.quality_gates.test // "null"' bmad/config.yaml 2>/dev/null)
    lint=$(yq -r '.ralph.defaults.quality_gates.lint // "null"' bmad/config.yaml 2>/dev/null)
    build=$(yq -r '.ralph.defaults.quality_gates.build // "null"' bmad/config.yaml 2>/dev/null)

    # Handle empty strings as null
    [[ -z "$typecheck" ]] && typecheck="null"
    [[ -z "$test" ]] && test="null"
    [[ -z "$lint" ]] && lint="null"
    [[ -z "$build" ]] && build="null"
  else
    # v1: Read from config.json
    project=$(jq -r '.project // "Unknown"' "$prd_file")
    branch=$(jq -r '.branchName // "Unknown"' "$prd_file")
    sprint_status_path=$(jq -r '.sprintStatusPath // "docs/sprint-status.yaml"' "$prd_file")

    # Configuration
    max_iterations=$(jq -r '.config.maxIterations // 50' "$prd_file")
    stuck_threshold=$(jq -r '.config.stuckThreshold // 3' "$prd_file")

    # Quality gates
    typecheck=$(jq -r '.config.qualityGates.typecheck // null' "$prd_file")
    test=$(jq -r '.config.qualityGates.test // null' "$prd_file")
    lint=$(jq -r '.config.qualityGates.lint // null' "$prd_file")
    build=$(jq -r '.config.qualityGates.build // null' "$prd_file")
  fi

  # Statistics
  local iterations_run=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
  local stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")
  local avg_iterations=$(jq -r '.stats.averageIterationsPerStory // 0' "$prd_file")

  # Story counts - read from sprint-status.yaml for accurate totals
  local total_stories=0
  local pending_stories=0

  if [[ -f "$sprint_status_path" ]]; then
    # Count total stories from sprint-status.yaml (support both epics and sprints formats)
    total_stories=$(yq eval '[.epics[].stories[] // .sprints[].stories[]] | length' "$sprint_status_path" 2>/dev/null || echo "0")
    # Count pending stories (not_started or in_progress, support both underscore and hyphen)
    pending_stories=$(yq eval '[.epics[].stories[] | select(.status == "not_started" or .status == "not-started" or .status == "in_progress" or .status == "in-progress")] | length' "$sprint_status_path" 2>/dev/null || echo "0")
    # Fallback for sprints format
    if [[ "$total_stories" == "0" ]] || [[ "$total_stories" == "null" ]]; then
      total_stories=$(yq eval '[.sprints[].stories[]] | length' "$sprint_status_path" 2>/dev/null || echo "0")
      pending_stories=$(yq eval '[.sprints[].stories[] | select(.status == "not_started" or .status == "not-started" or .status == "in_progress" or .status == "in-progress")] | length' "$sprint_status_path" 2>/dev/null || echo "0")
    fi
  fi

  # Fallback to storyAttempts length if sprint-status not available
  if [[ "$total_stories" == "0" ]] || [[ "$total_stories" == "null" ]]; then
    total_stories=$(jq -r '.storyAttempts | length' "$prd_file")
  fi

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

  # Get story title, points, and epic info from sprint-status.yaml if we have a current story
  local current_story_points=0
  local current_epic_id=""
  local current_epic_name=""
  local epic_total_points=0
  local epic_completed_points=0

  if [[ -n "$current_story" ]] && [[ -f "$sprint_status_path" ]]; then
    current_story_title=$(yq eval ".epics[].stories[] | select(.id == \"$current_story\") | .title" "$sprint_status_path" 2>/dev/null | head -1)
    current_story_points=$(yq eval ".epics[].stories[] | select(.id == \"$current_story\") | .points" "$sprint_status_path" 2>/dev/null | head -1)

    # Get epic info for current story
    current_epic_id=$(yq eval ".epics[] | select(.stories[].id == \"$current_story\") | .id" "$sprint_status_path" 2>/dev/null | head -1)

    if [[ -n "$current_epic_id" ]]; then
      current_epic_name=$(yq eval ".epics[] | select(.id == \"$current_epic_id\") | .name" "$sprint_status_path" 2>/dev/null)
      epic_total_points=$(yq eval ".epics[] | select(.id == \"$current_epic_id\") | .total_points" "$sprint_status_path" 2>/dev/null)
      epic_completed_points=$(yq eval ".epics[] | select(.id == \"$current_epic_id\") | .completed_points" "$sprint_status_path" 2>/dev/null)
    fi
  fi

  # Calculate time elapsed on current story
  local time_elapsed=""
  if [[ -n "$current_story" ]] && [[ -f "$progress_file" ]]; then
    # Find the first occurrence of current story in progress.txt (when it started)
    local story_start_line=$(grep -n "^## Iteration [0-9]\\+ - $current_story" "$progress_file" | head -1 | cut -d: -f1)

    if [[ -n "$story_start_line" ]]; then
      # Try to extract timestamp from Completed/Learning lines after the iteration header
      # Format typically: "Completed: ... at 2026-01-11T03:41:47Z" or similar
      # Or we can use file modification time as fallback

      # Get the file modification time as a reasonable approximation
      # This shows how long since the progress file was last updated
      local current_time=$(date +%s)
      local file_mod_time=$(stat -f %m "$progress_file" 2>/dev/null || stat -c %Y "$progress_file" 2>/dev/null)

      if [[ -n "$file_mod_time" ]]; then
        local elapsed_seconds=$((current_time - file_mod_time))

        # Format elapsed time nicely
        local days=$((elapsed_seconds / 86400))
        local hours=$(((elapsed_seconds % 86400) / 3600))
        local minutes=$(((elapsed_seconds % 3600) / 60))
        local seconds=$((elapsed_seconds % 60))

        if [[ $days -gt 0 ]]; then
          time_elapsed="${days}d ${hours}h ${minutes}m"
        elif [[ $hours -gt 0 ]]; then
          time_elapsed="${hours}h ${minutes}m"
        elif [[ $minutes -gt 0 ]]; then
          time_elapsed="${minutes}m ${seconds}s"
        else
          time_elapsed="${seconds}s"
        fi
      fi
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

    # Show story points
    if [[ -n "$current_story_points" ]] && [[ "$current_story_points" != "0" ]]; then
      echo "Points:         $current_story_points"
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

    # Show time elapsed
    if [[ -n "$time_elapsed" ]]; then
      echo "Time Elapsed:   $time_elapsed"
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

  # Estimated Time
  section "Estimated Time"
  if [[ $stories_completed -lt 2 ]]; then
    echo "${COLOR_DIM}Calculating... (need at least 2 completed stories)${COLOR_RESET}"
  else
    # Get all completion timestamps and sort them
    local timestamps=($(jq -r '.storyNotes | to_entries[] | .value.completedAt' "$prd_file" 2>/dev/null | grep -v "null" | sort))

    if [[ ${#timestamps[@]} -ge 2 ]]; then
      # Calculate time differences between consecutive completions
      local total_duration=0
      local duration_count=0

      for ((i=1; i<${#timestamps[@]}; i++)); do
        local prev_time="${timestamps[$((i-1))]}"
        local curr_time="${timestamps[$i]}"

        # Convert ISO 8601 timestamps to seconds (macOS and Linux compatible)
        local prev_seconds=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$prev_time" "+%s" 2>/dev/null || date -d "$prev_time" "+%s" 2>/dev/null)
        local curr_seconds=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$curr_time" "+%s" 2>/dev/null || date -d "$curr_time" "+%s" 2>/dev/null)

        if [[ -n "$prev_seconds" ]] && [[ -n "$curr_seconds" ]]; then
          local duration=$((curr_seconds - prev_seconds))
          total_duration=$((total_duration + duration))
          duration_count=$((duration_count + 1))
        fi
      done

      if [[ $duration_count -gt 0 ]]; then
        local avg_seconds_per_story=$((total_duration / duration_count))
        local remaining_stories=$((total_stories - stories_completed))
        local estimated_seconds=$((remaining_stories * avg_seconds_per_story))

        # Format average time per story
        local avg_time=""
        if [[ $avg_seconds_per_story -ge 3600 ]]; then
          local avg_hours=$((avg_seconds_per_story / 3600))
          local avg_minutes=$(((avg_seconds_per_story % 3600) / 60))
          avg_time="${avg_hours}h ${avg_minutes}m"
        elif [[ $avg_seconds_per_story -ge 60 ]]; then
          local avg_minutes=$((avg_seconds_per_story / 60))
          local avg_seconds=$((avg_seconds_per_story % 60))
          avg_time="${avg_minutes}m ${avg_seconds}s"
        else
          avg_time="${avg_seconds_per_story}s"
        fi

        # Format estimated remaining time
        local eta_time=""
        if [[ $estimated_seconds -ge 86400 ]]; then
          local eta_days=$((estimated_seconds / 86400))
          local eta_hours=$(((estimated_seconds % 86400) / 3600))
          local eta_minutes=$(((estimated_seconds % 3600) / 60))
          eta_time="${eta_days}d ${eta_hours}h ${eta_minutes}m"
        elif [[ $estimated_seconds -ge 3600 ]]; then
          local eta_hours=$((estimated_seconds / 3600))
          local eta_minutes=$(((estimated_seconds % 3600) / 60))
          eta_time="${eta_hours}h ${eta_minutes}m"
        elif [[ $estimated_seconds -ge 60 ]]; then
          local eta_minutes=$((estimated_seconds / 60))
          local eta_seconds=$((estimated_seconds % 60))
          eta_time="${eta_minutes}m ${eta_seconds}s"
        else
          eta_time="${estimated_seconds}s"
        fi

        echo "Avg Time/Story: $avg_time"
        echo "Remaining:      $remaining_stories stories"
        echo "ETA:            $eta_time"
      else
        echo "${COLOR_DIM}Calculating... (insufficient timestamp data)${COLOR_RESET}"
      fi
    else
      echo "${COLOR_DIM}Calculating... (need at least 2 completed stories)${COLOR_RESET}"
    fi
  fi
  echo ""

  # Quality Gates
  section "Quality Gates"
  local gates_enabled=0

  # Parse most recent quality gate execution from progress.txt
  local last_gate_result=""
  local last_gate_time=""
  local failed_gates=()

  if [[ -f "$progress_file" ]]; then
    # Search backwards for the most recent quality gate result
    local in_gate_section=false
    local found_result=false

    # Read file backwards (tail gives us recent lines first)
    while IFS= read -r line; do
      # Found a gate result section
      if [[ "$line" =~ "Quality gates: All passed" ]]; then
        last_gate_result="passed"
        found_result=true
        break
      elif [[ "$line" =~ "QUALITY GATES FAILED" ]]; then
        last_gate_result="failed"
        in_gate_section=true
      elif [[ $in_gate_section == true ]]; then
        # Collect failed gates
        if [[ "$line" =~ "Failed gates:" ]]; then
          continue
        elif [[ "$line" =~ "Timestamp: "* ]]; then
          last_gate_time="${line#Timestamp: }"
          found_result=true
          break
        elif [[ -n "$line" ]] && [[ ! "$line" =~ ^## ]]; then
          # This is a failed gate line
          failed_gates+=("$line")
        fi
      fi

      # Extract timestamp from completion or failure section
      if [[ $found_result == false ]] && [[ "$line" =~ "Timestamp: "* ]]; then
        last_gate_time="${line#Timestamp: }"
      fi
    done < <(tac "$progress_file" 2>/dev/null || tail -r "$progress_file" 2>/dev/null || tail -100 "$progress_file")
  fi

  # Format last execution time
  local time_ago=""
  if [[ -n "$last_gate_time" ]]; then
    local gate_seconds=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$last_gate_time" "+%s" 2>/dev/null || date -d "$last_gate_time" "+%s" 2>/dev/null)
    local now_seconds=$(date "+%s")
    local time_diff=$((now_seconds - gate_seconds))

    if [[ $time_diff -lt 60 ]]; then
      time_ago="${time_diff}s ago"
    elif [[ $time_diff -lt 3600 ]]; then
      time_ago="$((time_diff / 60))m ago"
    elif [[ $time_diff -lt 86400 ]]; then
      time_ago="$((time_diff / 3600))h ago"
    else
      time_ago="$((time_diff / 86400))d ago"
    fi
  fi

  # Display gates with status
  if [[ "$typecheck" != "null" ]]; then
    ((gates_enabled++))
    if [[ "$last_gate_result" == "passed" ]]; then
      echo "${COLOR_GREEN}✓${COLOR_RESET} Typecheck:  ${COLOR_GREEN}PASS${COLOR_RESET}"
    elif [[ "$last_gate_result" == "failed" ]]; then
      # Check if typecheck was in failed gates
      local failed=false
      for gate in "${failed_gates[@]}"; do
        [[ "$gate" =~ [Tt]ypecheck ]] && failed=true && break
      done
      if [[ $failed == true ]]; then
        echo "${COLOR_RED}✗${COLOR_RESET} Typecheck:  ${COLOR_RED}FAIL${COLOR_RESET}"
      else
        echo "${COLOR_GREEN}✓${COLOR_RESET} Typecheck:  ${COLOR_GREEN}PASS${COLOR_RESET}"
      fi
    else
      echo "${COLOR_DIM}○${COLOR_RESET} Typecheck:  ${COLOR_DIM}NO DATA${COLOR_RESET}"
    fi
  else
    echo "${COLOR_DIM}○ Typecheck:  (disabled)${COLOR_RESET}"
  fi

  if [[ "$test" != "null" ]]; then
    ((gates_enabled++))
    if [[ "$last_gate_result" == "passed" ]]; then
      echo "${COLOR_GREEN}✓${COLOR_RESET} Test:       ${COLOR_GREEN}PASS${COLOR_RESET}"
    elif [[ "$last_gate_result" == "failed" ]]; then
      local failed=false
      for gate in "${failed_gates[@]}"; do
        [[ "$gate" =~ [Tt]est ]] && failed=true && break
      done
      if [[ $failed == true ]]; then
        echo "${COLOR_RED}✗${COLOR_RESET} Test:       ${COLOR_RED}FAIL${COLOR_RESET}"
      else
        echo "${COLOR_GREEN}✓${COLOR_RESET} Test:       ${COLOR_GREEN}PASS${COLOR_RESET}"
      fi
    else
      echo "${COLOR_DIM}○${COLOR_RESET} Test:       ${COLOR_DIM}NO DATA${COLOR_RESET}"
    fi
  else
    echo "${COLOR_DIM}○ Test:       (disabled)${COLOR_RESET}"
  fi

  if [[ "$lint" != "null" ]]; then
    ((gates_enabled++))
    if [[ "$last_gate_result" == "passed" ]]; then
      echo "${COLOR_GREEN}✓${COLOR_RESET} Lint:       ${COLOR_GREEN}PASS${COLOR_RESET}"
    elif [[ "$last_gate_result" == "failed" ]]; then
      local failed=false
      for gate in "${failed_gates[@]}"; do
        [[ "$gate" =~ [Ll]int ]] && failed=true && break
      done
      if [[ $failed == true ]]; then
        echo "${COLOR_RED}✗${COLOR_RESET} Lint:       ${COLOR_RED}FAIL${COLOR_RESET}"
      else
        echo "${COLOR_GREEN}✓${COLOR_RESET} Lint:       ${COLOR_GREEN}PASS${COLOR_RESET}"
      fi
    else
      echo "${COLOR_DIM}○${COLOR_RESET} Lint:       ${COLOR_DIM}NO DATA${COLOR_RESET}"
    fi
  else
    echo "${COLOR_DIM}○ Lint:       (disabled)${COLOR_RESET}"
  fi

  if [[ "$build" != "null" ]]; then
    ((gates_enabled++))
    if [[ "$last_gate_result" == "passed" ]]; then
      echo "${COLOR_GREEN}✓${COLOR_RESET} Build:      ${COLOR_GREEN}PASS${COLOR_RESET}"
    elif [[ "$last_gate_result" == "failed" ]]; then
      local failed=false
      for gate in "${failed_gates[@]}"; do
        [[ "$gate" =~ [Bb]uild ]] && failed=true && break
      done
      if [[ $failed == true ]]; then
        echo "${COLOR_RED}✗${COLOR_RESET} Build:      ${COLOR_RED}FAIL${COLOR_RESET}"
      else
        echo "${COLOR_GREEN}✓${COLOR_RESET} Build:      ${COLOR_GREEN}PASS${COLOR_RESET}"
      fi
    else
      echo "${COLOR_DIM}○${COLOR_RESET} Build:      ${COLOR_DIM}NO DATA${COLOR_RESET}"
    fi
  else
    echo "${COLOR_DIM}○ Build:      (disabled)${COLOR_RESET}"
  fi

  if [[ $gates_enabled -eq 0 ]]; then
    echo ""
    warn "No quality gates enabled"
  elif [[ -n "$time_ago" ]]; then
    echo ""
    echo "${COLOR_DIM}Last run: $time_ago${COLOR_RESET}"
  fi
  echo ""

  # Recent Activity
  section "Recent Activity"
  if [[ -f "$progress_file" ]]; then
    # Show last 10 lines with key event highlighting
    local lines=$(tail -30 "$progress_file" | grep -v "^$" | tail -10)

    if [[ -n "$lines" ]]; then
      while IFS= read -r line; do
        # Highlight key events
        if [[ "$line" =~ ^##\ Iteration\ [0-9]+\ -\ STORY- ]]; then
          # Iteration start - cyan
          echo -e "${COLOR_CYAN}${line}${COLOR_RESET}"
        elif [[ "$line" =~ ^Completed: ]]; then
          # Story completion - green
          echo -e "${COLOR_GREEN}${line}${COLOR_RESET}"
        elif [[ "$line" =~ QUALITY\ GATES\ FAILED ]] || [[ "$line" =~ Failed\ gates: ]]; then
          # Quality gate failure - red
          echo -e "${COLOR_RED}${line}${COLOR_RESET}"
        elif [[ "$line" =~ STUCK ]] || [[ "$line" =~ stuck\ threshold ]]; then
          # Stuck event - red
          echo -e "${COLOR_RED}${line}${COLOR_RESET}"
        elif [[ "$line" =~ INTERRUPTED ]] || [[ "$line" =~ interrupted ]]; then
          # Interruption - yellow
          echo -e "${COLOR_YELLOW}${line}${COLOR_RESET}"
        elif [[ "$line" =~ Quality\ gates:\ All\ passed ]]; then
          # Quality gates passed - green
          echo -e "${COLOR_GREEN}${line}${COLOR_RESET}"
        else
          # Regular line
          echo "$line"
        fi
      done <<< "$lines"
    else
      echo "${COLOR_DIM}No recent activity${COLOR_RESET}"
    fi
  else
    echo "${COLOR_DIM}No activity log found${COLOR_RESET}"
  fi
}
