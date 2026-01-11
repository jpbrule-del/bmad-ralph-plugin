#!/usr/bin/env bash
# ralph list - List all loops

# Use the LIB_DIR variable from main script, or fallback to relative path
readonly LIST_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

cmd_list() {
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
        local prd_file="$loop_dir/config.json"

        if [[ -f "$prd_file" ]]; then
          local created_at=$(jq -r '.generatedAt // "Unknown"' "$prd_file")
          local iterations=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
          local stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")

          # Count total stories from storyAttempts
          local total_stories=$(jq -r '.storyAttempts | length' "$prd_file")

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
        local prd_file="$loop_dir/config.json"
        local feedback_file="$loop_dir/feedback.json"

        if [[ -f "$prd_file" ]]; then
          local created_at=$(jq -r '.generatedAt // "Unknown"' "$prd_file")
          local iterations=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
          local stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")

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
