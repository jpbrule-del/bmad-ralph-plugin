#!/usr/bin/env bash
# ralph feedback-report - Generate aggregate feedback analytics

# Use the LIB_DIR variable from main script, or fallback to relative path
readonly FEEDBACK_REPORT_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

# Source required utilities
source "$FEEDBACK_REPORT_LIB_DIR/core/output.sh"

cmd_feedback_report() {
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
        echo "Usage: ralph feedback-report [--json]"
        exit 1
        ;;
      *)
        error "Unexpected argument: $1"
        echo "Usage: ralph feedback-report [--json]"
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

  local archive_dir="ralph/archive"

  # Check if archive directory exists
  if [[ ! -d "$archive_dir" ]]; then
    if [[ "$json_output" == "true" ]]; then
      echo '{"archivedLoops":0,"analytics":{"averageSatisfaction":null,"totalFeedback":0,"successRate":null,"themes":[]}}'
      exit 0
    else
      info "No archived loops found in $archive_dir"
      echo ""
      echo "Archive loops using 'ralph archive <loop-name>' to collect feedback."
      exit 0
    fi
  fi

  # Collect all feedback data
  local -a feedback_files=()
  local -a satisfaction_scores=()
  local -a worked_well=()
  local -a should_improve=()
  local yes_count=0
  local no_count=0
  local total_feedback=0
  local total_stories=0
  local total_iterations=0
  local manual_interventions=0

  # Find all archived loops with feedback
  while IFS= read -r -d '' feedback_file; do
    if [[ -f "$feedback_file" ]]; then
      feedback_files+=("$feedback_file")

      # Extract satisfaction score
      local satisfaction
      satisfaction=$(jq -r '.responses.satisfaction // empty' "$feedback_file" 2>/dev/null)
      if [[ -n "$satisfaction" ]] && [[ "$satisfaction" != "null" ]]; then
        satisfaction_scores+=("$satisfaction")
      fi

      # Extract worked well
      local worked
      worked=$(jq -r '.responses.workedWell // empty' "$feedback_file" 2>/dev/null)
      if [[ -n "$worked" ]] && [[ "$worked" != "null" ]]; then
        worked_well+=("$worked")
      fi

      # Extract should improve
      local improve
      improve=$(jq -r '.responses.shouldImprove // empty' "$feedback_file" 2>/dev/null)
      if [[ -n "$improve" ]] && [[ "$improve" != "null" ]]; then
        should_improve+=("$improve")
      fi

      # Extract would run again
      local would_run
      would_run=$(jq -r '.responses.wouldRunAgain // empty' "$feedback_file" 2>/dev/null)
      if [[ "$would_run" == "yes" ]]; then
        ((yes_count++))
      elif [[ "$would_run" == "no" ]]; then
        ((no_count++))
      fi

      # Extract loop stats
      local stories
      stories=$(jq -r '.loopStats.storiesCompleted // 0' "$feedback_file" 2>/dev/null)
      total_stories=$((total_stories + stories))

      local iterations
      iterations=$(jq -r '.loopStats.iterationsRun // 0' "$feedback_file" 2>/dev/null)
      total_iterations=$((total_iterations + iterations))

      local interventions
      interventions=$(jq -r '.responses.manualInterventions // 0' "$feedback_file" 2>/dev/null)
      manual_interventions=$((manual_interventions + interventions))

      ((total_feedback++))
    fi
  done < <(find "$archive_dir" -name "feedback.json" -print0 2>/dev/null)

  # Check if we have any feedback
  if [[ ${#feedback_files[@]} -eq 0 ]]; then
    if [[ "$json_output" == "true" ]]; then
      echo '{"archivedLoops":0,"analytics":{"averageSatisfaction":null,"totalFeedback":0,"successRate":null,"themes":[]}}'
      exit 0
    else
      info "No feedback found in archived loops"
      echo ""
      echo "Archived loops exist but don't have feedback yet."
      echo "Archive new loops to collect feedback data."
      exit 0
    fi
  fi

  # Calculate average satisfaction
  local avg_satisfaction="N/A"
  if [[ ${#satisfaction_scores[@]} -gt 0 ]]; then
    local sum=0
    for score in "${satisfaction_scores[@]}"; do
      sum=$((sum + score))
    done
    avg_satisfaction=$(awk "BEGIN {printf \"%.2f\", $sum / ${#satisfaction_scores[@]}}")
  fi

  # Calculate success rate
  local success_rate="N/A"
  local total_responses=$((yes_count + no_count))
  if [[ $total_responses -gt 0 ]]; then
    success_rate=$(awk "BEGIN {printf \"%.1f\", ($yes_count / $total_responses) * 100}")
  fi

  # Output results
  if [[ "$json_output" == "true" ]]; then
    # JSON output
    local themes_json="[]"
    if [[ ${#worked_well[@]} -gt 0 ]] || [[ ${#should_improve[@]} -gt 0 ]]; then
      local worked_json
      worked_json=$(printf '%s\n' "${worked_well[@]}" | jq -R . | jq -s .)
      local improve_json
      improve_json=$(printf '%s\n' "${should_improve[@]}" | jq -R . | jq -s .)
      themes_json=$(jq -n \
        --argjson worked "$worked_json" \
        --argjson improve "$improve_json" \
        '{workedWell: $worked, shouldImprove: $improve}')
    fi

    jq -n \
      --argjson loops "${#feedback_files[@]}" \
      --arg avg "$avg_satisfaction" \
      --argjson total "$total_feedback" \
      --arg rate "$success_rate" \
      --argjson yes "$yes_count" \
      --argjson no "$no_count" \
      --argjson stories "$total_stories" \
      --argjson iterations "$total_iterations" \
      --argjson interventions "$manual_interventions" \
      --argjson themes "$themes_json" \
      '{
        archivedLoops: $loops,
        analytics: {
          averageSatisfaction: $avg,
          totalFeedback: $total,
          successRate: $rate,
          wouldRunAgain: {yes: $yes, no: $no},
          totalStoriesCompleted: $stories,
          totalIterations: $iterations,
          manualInterventions: $interventions,
          themes: $themes
        }
      }'
  else
    # Human-readable output
    section "Feedback Analytics Report"
    echo ""

    info "Overview"
    echo "  Archived loops analyzed:  $total_feedback"
    echo "  Total stories completed:  $total_stories"
    echo "  Total iterations run:     $total_iterations"
    echo ""

    section "Satisfaction Metrics"
    echo ""

    # Display average satisfaction with color coding
    if [[ "$avg_satisfaction" != "N/A" ]]; then
      local sat_int=${avg_satisfaction%.*}
      local color=""
      if [[ $sat_int -ge 4 ]]; then
        color="$COLOR_SUCCESS"
      elif [[ $sat_int -ge 3 ]]; then
        color="$COLOR_WARNING"
      else
        color="$COLOR_ERROR"
      fi
      echo -e "  Average satisfaction:     ${color}${avg_satisfaction}/5.0${COLOR_RESET}"
    else
      echo "  Average satisfaction:     N/A"
    fi

    # Satisfaction score distribution
    if [[ ${#satisfaction_scores[@]} -gt 0 ]]; then
      echo ""
      echo "  Satisfaction distribution:"
      for i in 5 4 3 2 1; do
        local count=0
        for score in "${satisfaction_scores[@]}"; do
          if [[ $score -eq $i ]]; then
            ((count++))
          fi
        done
        if [[ $count -gt 0 ]]; then
          local percentage=$(awk "BEGIN {printf \"%.0f\", ($count / ${#satisfaction_scores[@]}) * 100}")
          local bar=""
          local bar_length=$((percentage / 2))
          for ((j=0; j<bar_length; j++)); do
            bar="${bar}█"
          done
          echo -e "    $i ⭐: ${bar} ${count} (${percentage}%)"
        fi
      done
    fi

    echo ""
    section "Success Rate"
    echo ""

    if [[ "$success_rate" != "N/A" ]]; then
      local rate_int=${success_rate%.*}
      local color=""
      if [[ $rate_int -ge 75 ]]; then
        color="$COLOR_SUCCESS"
      elif [[ $rate_int -ge 50 ]]; then
        color="$COLOR_WARNING"
      else
        color="$COLOR_ERROR"
      fi
      echo -e "  Would run config again:   ${color}${success_rate}%${COLOR_RESET}"
    else
      echo "  Would run config again:   N/A"
    fi

    echo "  Yes: $yes_count  |  No: $no_count"
    echo ""

    section "Manual Interventions"
    echo ""
    echo "  Total manual fixes:       $manual_interventions stories"
    if [[ $total_stories -gt 0 ]]; then
      local intervention_rate=$(awk "BEGIN {printf \"%.1f\", ($manual_interventions / $total_stories) * 100}")
      echo "  Intervention rate:        ${intervention_rate}%"
    fi
    echo ""

    # Display common themes
    section "Feedback Themes"
    echo ""

    if [[ ${#worked_well[@]} -gt 0 ]]; then
      success "What Worked Well (${#worked_well[@]} responses):"
      echo ""
      local idx=1
      for response in "${worked_well[@]}"; do
        # Truncate long responses for readability
        local truncated="$response"
        if [[ ${#response} -gt 100 ]]; then
          truncated="${response:0:97}..."
        fi
        echo "  $idx. $truncated"
        ((idx++))
      done
      echo ""
    fi

    if [[ ${#should_improve[@]} -gt 0 ]]; then
      warn "What Should Improve (${#should_improve[@]} responses):"
      echo ""
      local idx=1
      for response in "${should_improve[@]}"; do
        # Truncate long responses for readability
        local truncated="$response"
        if [[ ${#response} -gt 100 ]]; then
          truncated="${response:0:97}..."
        fi
        echo "  $idx. $truncated"
        ((idx++))
      done
      echo ""
    fi

    info "Run 'ralph show <loop-name>' to view detailed feedback for specific loops"
  fi
}
