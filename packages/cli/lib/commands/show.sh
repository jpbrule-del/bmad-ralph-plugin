#!/usr/bin/env bash
# ralph show - Show loop details

cmd_show() {
  local loop_name=""
  local json_output=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        json_output=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph show <loop-name> [--json]"
        exit 1
        ;;
      *)
        if [[ -z "$loop_name" ]]; then
          loop_name="$1"
        else
          error "Unexpected argument: $1"
          echo "Usage: ralph show <loop-name> [--json]"
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate loop name provided
  if [[ -z "$loop_name" ]]; then
    error "Loop name is required"
    echo "Usage: ralph show <loop-name> [--json]"
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

  # Extract data from prd.json
  local project=$(jq -r '.project // "Unknown"' "$prd_file")
  local branch=$(jq -r '.branchName // "Unknown"' "$prd_file")
  local description=$(jq -r '.description // ""' "$prd_file")
  local created_at=$(jq -r '.generatedAt // "Unknown"' "$prd_file")
  local sprint_status_path=$(jq -r '.sprintStatusPath // "docs/sprint-status.yaml"' "$prd_file")

  # Configuration
  local max_iterations=$(jq -r '.config.maxIterations // 50' "$prd_file")
  local stuck_threshold=$(jq -r '.config.stuckThreshold // 3' "$prd_file")
  local custom_instructions=$(jq -r '.config.customInstructions // null' "$prd_file")

  # Quality gates
  local typecheck=$(jq -r '.config.qualityGates.typecheck // null' "$prd_file")
  local test=$(jq -r '.config.qualityGates.test // null' "$prd_file")
  local lint=$(jq -r '.config.qualityGates.lint // null' "$prd_file")
  local build=$(jq -r '.config.qualityGates.build // null' "$prd_file")

  # Statistics
  local iterations_run=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
  local stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")
  local started_at=$(jq -r '.stats.startedAt // null' "$prd_file")
  local completed_at=$(jq -r '.stats.completedAt // null' "$prd_file")

  # Story progress
  local total_stories=$(jq -r '.storyAttempts | length' "$prd_file")
  local story_attempts=$(jq -r '.storyAttempts // {}' "$prd_file")

  # Determine last activity timestamp
  local last_activity="$created_at"
  if [[ "$completed_at" != "null" ]]; then
    last_activity="$completed_at"
  elif [[ "$started_at" != "null" ]]; then
    last_activity="$started_at"
  fi

  # Output results
  if [[ "$json_output" == "true" ]]; then
    # JSON output - just output the prd.json with some additional fields
    jq '. + {
      "loopName": "'"$loop_name"'",
      "isArchived": '"$([ "$is_archived" == "true" ] && echo "true" || echo "false")"',
      "lastActivity": "'"$last_activity"'"
    }' "$prd_file"
  else
    # Human-readable output
    header "Loop Details: $loop_name"
    echo ""

    # Status
    if [[ "$is_archived" == "true" ]]; then
      echo "${COLOR_YELLOW}Status:${COLOR_RESET}         Archived (read-only)"
    else
      echo "${COLOR_GREEN}Status:${COLOR_RESET}         Active"
    fi
    echo ""

    # Project information
    section "Project Information"
    echo "Project:        $project"
    echo "Branch:         $branch"
    echo "Created:        $created_at"
    echo "Last Activity:  $last_activity"
    if [[ -n "$description" ]]; then
      echo "Description:    $description"
    fi
    echo "Sprint Status:  $sprint_status_path"
    echo ""

    # Configuration
    section "Configuration"
    echo "Max Iterations:   $max_iterations"
    echo "Stuck Threshold:  $stuck_threshold"
    if [[ "$custom_instructions" != "null" ]]; then
      echo "Custom Instructions: $custom_instructions"
    fi
    echo ""

    # Quality gates
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

    echo ""
    if [[ $gates_enabled -eq 0 ]]; then
      warn "No quality gates enabled"
    fi

    # Execution statistics
    section "Execution Statistics"
    echo "Iterations Run:     $iterations_run"
    echo "Stories Completed:  $stories_completed / $total_stories"

    # Calculate completion percentage
    if [[ $total_stories -gt 0 ]]; then
      local percent=$((stories_completed * 100 / total_stories))
      echo "Completion:         $percent%"
    fi

    if [[ "$started_at" != "null" ]]; then
      echo "Started At:         $started_at"
    fi

    if [[ "$completed_at" != "null" ]]; then
      echo "Completed At:       $completed_at"
    fi

    # Average iterations per story
    if [[ $stories_completed -gt 0 ]]; then
      local avg=$((iterations_run / stories_completed))
      echo "Avg Iterations/Story: $avg"
    fi
    echo ""

    # Story progress breakdown
    section "Story Progress"

    if [[ $total_stories -eq 0 ]]; then
      echo "No stories tracked yet"
    else
      # Show stories grouped by attempt count
      echo "Story Attempt Summary:"
      echo ""

      # Count stories by attempt count
      local attempts_1=$(echo "$story_attempts" | jq '[.[] | select(. == 1)] | length')
      local attempts_2=$(echo "$story_attempts" | jq '[.[] | select(. == 2)] | length')
      local attempts_3_plus=$(echo "$story_attempts" | jq '[.[] | select(. >= 3)] | length')

      echo "  ${COLOR_GREEN}1 attempt:${COLOR_RESET}   $attempts_1 stories"
      echo "  ${COLOR_YELLOW}2 attempts:${COLOR_RESET}  $attempts_2 stories"

      if [[ $attempts_3_plus -gt 0 ]]; then
        echo "  ${COLOR_RED}3+ attempts:${COLOR_RESET} $attempts_3_plus stories"
      else
        echo "  ${COLOR_DIM}3+ attempts: 0 stories${COLOR_RESET}"
      fi

      echo ""

      # Show individual stories with high attempt counts (potential stuck stories)
      local stuck_stories=$(echo "$story_attempts" | jq -r 'to_entries | map(select(.value >= '"$stuck_threshold"')) | .[] | "\(.key): \(.value) attempts"')

      if [[ -n "$stuck_stories" ]]; then
        warn "Stories at or above stuck threshold ($stuck_threshold):"
        echo "$stuck_stories" | while IFS= read -r line; do
          echo "  $line"
        done
        echo ""
      fi
    fi

    # Footer
    info "Loop location: $loop_path"
  fi
}
