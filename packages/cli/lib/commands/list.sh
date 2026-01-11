#!/usr/bin/env bash
# ralph list - List all loops (v2: BMAD-native)

# Use the LIB_DIR variable from main script, or fallback to relative path
readonly LIST_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

# Source required modules
source "$LIB_DIR/core/bmad_config.sh"
source "$LIB_DIR/core/migration.sh"

cmd_list() {
  # Check for migration (v1 -> v2)
  check_and_migrate
  local show_active=true
  local show_archived=true
  local json_output=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --active)
        show_active=true
        show_archived=false
        shift
        ;;
      --archived)
        show_active=false
        show_archived=true
        shift
        ;;
      --json)
        json_output=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        echo "Usage: ralph list [--active] [--archived] [--json]"
        exit 1
        ;;
      *)
        error "Unexpected argument: $1"
        echo "Usage: ralph list [--active] [--archived] [--json]"
        exit 1
        ;;
    esac
  done

  # Ensure ralph is initialized
  if [[ ! -d "ralph" ]]; then
    error "Ralph is not initialized in this project"
    echo "Run 'ralph init' to initialize"
    exit 1
  fi

  local loops_dir="ralph/loops"
  local archive_dir="ralph/archive"
  local loops_found=0

  # Collect loop data
  declare -a loop_data=()

  # Scan active loops
  if [[ "$show_active" == "true" ]] && [[ -d "$loops_dir" ]]; then
    for loop_dir in "$loops_dir"/*; do
      if [[ -d "$loop_dir" ]]; then
        local loop_name=$(basename "$loop_dir")
        local state_file="$loop_dir/.state.json"
        local config_file="$loop_dir/config.json"  # v1 legacy
        local prd_file=""

        # Determine state file (v2: .state.json, v1: config.json)
        if [[ -f "$state_file" ]]; then
          prd_file="$state_file"
        elif [[ -f "$config_file" ]]; then
          prd_file="$config_file"
        fi

        if [[ -n "$prd_file" ]] && [[ -f "$prd_file" ]]; then
          local created_at=""
          local iterations=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
          local stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")
          local total_stories=0

          # Get created_at from sprint-status.yaml (v2) or config.json (v1)
          local sprint_status_path=$(get_bmad_sprint_status_path 2>/dev/null || echo "docs/sprint-status.yaml")
          if [[ -f "$sprint_status_path" ]]; then
            created_at=$(yq eval ".ralph_loops[] | select(.name == \"$loop_name\") | .created_at" "$sprint_status_path" 2>/dev/null)
          fi
          # Fallback to config.json for v1
          if [[ -z "$created_at" ]] || [[ "$created_at" == "null" ]]; then
            if [[ -f "$config_file" ]]; then
              created_at=$(jq -r '.generatedAt // "Unknown"' "$config_file")
            else
              created_at="Unknown"
            fi
          fi

          # Count total stories from storyAttempts or sprint-status.yaml
          total_stories=$(jq -r '.storyAttempts | length' "$prd_file" 2>/dev/null || echo "0")
          if [[ "$total_stories" == "0" ]] && [[ -f "$sprint_status_path" ]]; then
            total_stories=$(yq eval '[.epics[].stories[]] | length' "$sprint_status_path" 2>/dev/null || echo "0")
          fi

          # Active loops don't have archive date or feedback
          loop_data+=("active|$loop_name|$created_at|$stories_completed|$total_stories|$iterations|N/A|N/A")
          ((loops_found++))
        fi
      fi
    done
  fi

  # Scan archived loops
  if [[ "$show_archived" == "true" ]] && [[ -d "$archive_dir" ]]; then
    for loop_dir in "$archive_dir"/*; do
      if [[ -d "$loop_dir" ]]; then
        local loop_name=$(basename "$loop_dir")
        local state_file="$loop_dir/.state.json"
        local config_file="$loop_dir/config.json"  # v1 legacy
        local prd_file=""
        local feedback_file="$loop_dir/feedback.json"

        # Determine state file (v2: .state.json, v1: config.json)
        if [[ -f "$state_file" ]]; then
          prd_file="$state_file"
        elif [[ -f "$config_file" ]]; then
          prd_file="$config_file"
        fi

        if [[ -n "$prd_file" ]] && [[ -f "$prd_file" ]]; then
          local created_at=""
          local iterations=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
          local stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")

          # Get created_at from config.json for archived loops (v1 always has it)
          if [[ -f "$config_file" ]]; then
            created_at=$(jq -r '.generatedAt // "Unknown"' "$config_file")
          else
            created_at="Unknown"
          fi

          # Count total stories from storyAttempts
          local total_stories=$(jq -r '.storyAttempts | length' "$prd_file")

          # Extract archive date from directory name (YYYY-MM-DD prefix)
          local archive_date="Unknown"
          if [[ "$loop_name" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})- ]]; then
            archive_date="${BASH_REMATCH[1]}"
          fi

          # Extract feedback score if feedback.json exists
          local feedback_score="N/A"
          if [[ -f "$feedback_file" ]]; then
            feedback_score=$(jq -r '.responses.overallSatisfaction // "N/A"' "$feedback_file")
          fi

          loop_data+=("archived|$loop_name|$created_at|$stories_completed|$total_stories|$iterations|$archive_date|$feedback_score")
          ((loops_found++))
        fi
      fi
    done
  fi

  # Output results
  if [[ "$json_output" == "true" ]]; then
    # JSON output
    echo "{"
    echo "  \"loops\": ["

    local first=true
    for data in "${loop_data[@]+"${loop_data[@]}"}"; do
      [[ -z "$data" ]] && continue
      IFS='|' read -r status name created stories_completed total_stories iterations archive_date feedback_score <<< "$data"

      if [[ "$first" == "true" ]]; then
        first=false
      else
        echo ","
      fi

      echo "    {"
      echo "      \"name\": \"$name\","
      echo "      \"status\": \"$status\","
      echo "      \"createdAt\": \"$created\","
      echo "      \"storiesCompleted\": $stories_completed,"
      echo "      \"totalStories\": $total_stories,"
      echo "      \"iterations\": $iterations,"

      # Add archiveDate and feedbackScore for archived loops
      if [[ "$status" == "archived" ]]; then
        echo "      \"archiveDate\": \"$archive_date\","
        # Handle numeric vs N/A feedback scores in JSON
        if [[ "$feedback_score" == "N/A" ]]; then
          echo "      \"feedbackScore\": null"
        else
          echo "      \"feedbackScore\": $feedback_score"
        fi
      else
        echo "      \"archiveDate\": null,"
        echo "      \"feedbackScore\": null"
      fi
      echo -n "    }"
    done

    echo ""
    echo "  ],"
    echo "  \"total\": $loops_found"
    echo "}"
  else
    # Human-readable output
    if [[ $loops_found -eq 0 ]]; then
      info "No loops found"
      if [[ "$show_active" == "true" ]] && [[ "$show_archived" == "false" ]]; then
        echo "Use 'ralph create <name>' to create a new loop"
      fi
      return 0
    fi

    header "Ralph Loops"
    echo ""

    # Determine if we're showing only archived loops to adjust table format
    if [[ "$show_active" == "false" ]] && [[ "$show_archived" == "true" ]]; then
      # Show additional columns for archived-only view
      printf "%-25s %-10s %-13s %-15s %-12s %-10s\n" "NAME" "STATUS" "ARCHIVED" "STORIES" "ITERATIONS" "FEEDBACK"
      printf "%-25s %-10s %-13s %-15s %-12s %-10s\n" "----" "------" "--------" "-------" "----------" "--------"
    else
      # Standard view (active or mixed)
      printf "%-20s %-10s %-20s %-15s %-12s\n" "NAME" "STATUS" "CREATED" "STORIES" "ITERATIONS"
      printf "%-20s %-10s %-20s %-15s %-12s\n" "----" "------" "-------" "-------" "----------"
    fi

    # Print loop data
    for data in "${loop_data[@]+"${loop_data[@]}"}"; do
      [[ -z "$data" ]] && continue
      IFS='|' read -r status name created stories_completed total_stories iterations archive_date feedback_score <<< "$data"

      # Format created date (extract date part only)
      local created_date="${created%%T*}"

      # Format stories as "completed/total"
      local stories_str="$stories_completed/$total_stories"

      # Color code status
      local status_display
      if [[ "$status" == "active" ]]; then
        status_display="${COLOR_GREEN}active${COLOR_RESET}"
      else
        status_display="${COLOR_YELLOW}archived${COLOR_RESET}"
      fi

      # Format feedback score with color coding
      local feedback_display="$feedback_score"
      if [[ "$feedback_score" != "N/A" ]]; then
        # Color code feedback: 1-2 red, 3 yellow, 4-5 green
        if [[ "$feedback_score" -le 2 ]]; then
          feedback_display="${COLOR_RED}${feedback_score}/5${COLOR_RESET}"
        elif [[ "$feedback_score" -eq 3 ]]; then
          feedback_display="${COLOR_YELLOW}${feedback_score}/5${COLOR_RESET}"
        else
          feedback_display="${COLOR_GREEN}${feedback_score}/5${COLOR_RESET}"
        fi
      fi

      # Output format depends on view mode
      if [[ "$show_active" == "false" ]] && [[ "$show_archived" == "true" ]]; then
        # Archived-only view shows archive date and feedback
        printf "%-25s %-10b %-13s %-15s %-12s %-10b\n" \
          "$name" \
          "$status_display" \
          "$archive_date" \
          "$stories_str" \
          "$iterations" \
          "$feedback_display"
      else
        # Standard view shows created date
        printf "%-20s %-10b %-20s %-15s %-12s\n" \
          "$name" \
          "$status_display" \
          "$created_date" \
          "$stories_str" \
          "$iterations"
      fi
    done

    echo ""
    info "Total loops: $loops_found"
  fi
}
