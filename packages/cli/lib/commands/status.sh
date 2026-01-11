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
    # Show last 5 lines (excluding empty lines)
    tail -20 "$progress_file" | grep -v "^$" | tail -5
  else
    echo "${COLOR_DIM}No activity log found${COLOR_RESET}"
  fi
}
