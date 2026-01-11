#!/usr/bin/env bash
# questionnaire.sh - Feedback questionnaire for loop archival

# Collect feedback from user
# Arguments:
#   $1: loop_name - Name of the loop being archived
#   $2: prd_file - Path to prd.json file
# Outputs:
#   JSON string with feedback responses
# Returns: 0 on success, 1 on failure
collect_feedback() {
  local loop_name="$1"
  local prd_file="$2"

  if [[ -z "$loop_name" ]] || [[ -z "$prd_file" ]]; then
    error "collect_feedback requires loop_name and prd_file arguments"
    return 1
  fi

  # Extract loop stats
  local stories_completed
  local iterations_run
  local total_stories

  stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$prd_file")
  iterations_run=$(jq -r '.stats.iterationsRun // 0' "$prd_file")
  total_stories=$(jq -r '.storyAttempts | length' "$prd_file")

  # Display feedback collection header
  echo ""
  echo "${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo "${COLOR_CYAN}                    LOOP FEEDBACK COLLECTION                    ${COLOR_RESET}"
  echo "${COLOR_CYAN}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""
  echo "Loop: ${COLOR_BOLD}$loop_name${COLOR_RESET}"
  echo "Stories completed: $stories_completed / $total_stories"
  echo "Total iterations: $iterations_run"
  echo ""
  echo "Please take a moment to provide feedback on this loop execution."
  echo "Your feedback helps improve Ralph's effectiveness over time."
  echo ""
  echo "${COLOR_YELLOW}Note: All questions are required and cannot be skipped.${COLOR_RESET}"
  echo ""

  # Question 1: Overall satisfaction (1-5 scale)
  local satisfaction=""
  while true; do
    echo "${COLOR_BOLD}1. Overall Satisfaction${COLOR_RESET}"
    echo "   How satisfied are you with this loop's performance?"
    echo "   1 = Very Dissatisfied, 5 = Very Satisfied"
    echo ""
    read -rp "   Rating [1-5]: " satisfaction

    if [[ "$satisfaction" =~ ^[1-5]$ ]]; then
      break
    else
      echo ""
      warning "Please enter a number between 1 and 5"
      echo ""
    fi
  done

  # Question 2: Stories requiring manual intervention (count)
  local manual_interventions=""
  while true; do
    echo ""
    echo "${COLOR_BOLD}2. Manual Interventions${COLOR_RESET}"
    echo "   How many stories required manual intervention or fixing?"
    echo ""
    read -rp "   Count [0-$total_stories]: " manual_interventions

    # Default to 0 if empty
    manual_interventions="${manual_interventions:-0}"

    if [[ "$manual_interventions" =~ ^[0-9]+$ ]] && [[ "$manual_interventions" -ge 0 ]] && [[ "$manual_interventions" -le "$total_stories" ]]; then
      break
    else
      echo ""
      warning "Please enter a number between 0 and $total_stories"
      echo ""
    fi
  done

  # Question 3: What worked well? (required text)
  local worked_well=""
  while true; do
    echo ""
    echo "${COLOR_BOLD}3. What Worked Well?${COLOR_RESET}"
    echo "   Describe what aspects of this loop execution were successful."
    echo "   (Required - cannot be empty)"
    echo ""
    read -rp "   Your answer: " worked_well

    # Trim whitespace
    worked_well=$(echo "$worked_well" | xargs)

    if [[ -n "$worked_well" ]]; then
      break
    else
      echo ""
      warning "This question is required. Please provide an answer."
      echo ""
    fi
  done

  # Question 4: What should be improved? (required text)
  local should_improve=""
  while true; do
    echo ""
    echo "${COLOR_BOLD}4. What Should Be Improved?${COLOR_RESET}"
    echo "   Describe what aspects need improvement or didn't work well."
    echo "   (Required - cannot be empty)"
    echo ""
    read -rp "   Your answer: " should_improve

    # Trim whitespace
    should_improve=$(echo "$should_improve" | xargs)

    if [[ -n "$should_improve" ]]; then
      break
    else
      echo ""
      warning "This question is required. Please provide an answer."
      echo ""
    fi
  done

  # Question 5: Would you run this config again? (yes/no)
  local run_again=""
  while true; do
    echo ""
    echo "${COLOR_BOLD}5. Would You Run This Configuration Again?${COLOR_RESET}"
    echo "   Would you use this loop configuration for future sprints?"
    echo ""
    read -rp "   Yes or No [y/n]: " run_again

    # Convert to lowercase
    run_again=$(echo "$run_again" | tr '[:upper:]' '[:lower:]')

    if [[ "$run_again" == "y" ]] || [[ "$run_again" == "yes" ]]; then
      run_again="yes"
      break
    elif [[ "$run_again" == "n" ]] || [[ "$run_again" == "no" ]]; then
      run_again="no"
      break
    else
      echo ""
      warning "Please enter 'y' for yes or 'n' for no"
      echo ""
    fi
  done

  # Display feedback summary
  echo ""
  echo "${COLOR_CYAN}─────────────────────────────────────────────────────────────${COLOR_RESET}"
  echo "${COLOR_BOLD}Feedback Summary:${COLOR_RESET}"
  echo ""
  echo "Overall Satisfaction: $satisfaction/5"
  echo "Manual Interventions: $manual_interventions"
  echo "What Worked Well: $worked_well"
  echo "What Should Be Improved: $should_improve"
  echo "Run Again: $run_again"
  echo "${COLOR_CYAN}─────────────────────────────────────────────────────────────${COLOR_RESET}"
  echo ""

  # Confirm submission
  read -rp "Submit this feedback? [Y/n]: " confirm
  confirm="${confirm:-y}"
  confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

  if [[ "$confirm" != "y" ]] && [[ "$confirm" != "yes" ]]; then
    echo ""
    warning "Feedback submission cancelled. Loop will not be archived."
    return 1
  fi

  # Generate feedback JSON
  local feedback_json
  feedback_json=$(jq -n \
    --argjson satisfaction "$satisfaction" \
    --argjson manual_interventions "$manual_interventions" \
    --arg worked_well "$worked_well" \
    --arg should_improve "$should_improve" \
    --arg run_again "$run_again" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg loop_name "$loop_name" \
    --argjson stories_completed "$stories_completed" \
    --argjson total_stories "$total_stories" \
    --argjson iterations_run "$iterations_run" \
    '{
      loopName: $loop_name,
      timestamp: $timestamp,
      responses: {
        overallSatisfaction: $satisfaction,
        manualInterventions: $manual_interventions,
        workedWell: $worked_well,
        shouldImprove: $should_improve,
        runAgain: $run_again
      },
      loopStats: {
        storiesCompleted: $stories_completed,
        totalStories: $total_stories,
        iterationsRun: $iterations_run
      }
    }')

  echo "$feedback_json"
  return 0
}
