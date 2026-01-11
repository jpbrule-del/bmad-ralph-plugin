#!/usr/bin/env bash
# interactive.sh - Interactive prompts for loop configuration

# Prompt for epic filter
# Arguments:
#   $1: current_epic_filter - Current epic filter value (or empty)
# Returns: Selected epic ID or empty string for "all"
prompt_epic_filter() {
  local current_epic="${1:-}"

  # If epic already provided, return it
  if [[ -n "$current_epic" ]]; then
    echo "$current_epic"
    return 0
  fi

  # Source sprint analysis to get epic list
  local sprint_file
  sprint_file=$(get_sprint_status_path)

  if [[ -z "$sprint_file" ]]; then
    echo ""
    return 1
  fi

  # Get list of epics
  local -a epic_ids=()
  local -a epic_names=()

  while IFS= read -r epic_id; do
    epic_ids+=("$epic_id")
    local epic_name
    epic_name=$(get_epic_name "$epic_id")
    epic_names+=("$epic_name")
  done < <(get_all_epics)

  # Display prompt
  echo ""
  echo "Select epic filter:"
  echo "  0) All epics (default)"

  local i=1
  for idx in "${!epic_ids[@]}"; do
    echo "  $i) ${epic_ids[$idx]}: ${epic_names[$idx]}"
    ((i++))
  done

  echo ""
  read -rp "Enter choice [0]: " choice

  # Default to 0 (all epics)
  choice="${choice:-0}"

  # Validate choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    warning "Invalid choice, using all epics"
    echo ""
    return 0
  fi

  if [[ "$choice" -eq 0 ]]; then
    echo ""
    return 0
  fi

  local epic_index=$((choice - 1))
  if [[ $epic_index -ge 0 ]] && [[ $epic_index -lt ${#epic_ids[@]} ]]; then
    echo "${epic_ids[$epic_index]}"
    return 0
  else
    warning "Invalid choice, using all epics"
    echo ""
    return 0
  fi
}

# Prompt for max iterations
# Arguments:
#   $1: default_value - Default max iterations (default: 50)
# Returns: Selected max iterations value
prompt_max_iterations() {
  local default="${1:-50}"

  echo ""
  read -rp "Max iterations [$default]: " value

  # Use default if empty
  value="${value:-$default}"

  # Validate it's a positive integer
  if [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$value"
    return 0
  else
    warning "Invalid value, using default: $default"
    echo "$default"
    return 0
  fi
}

# Prompt for stuck threshold
# Arguments:
#   $1: default_value - Default stuck threshold (default: 3)
# Returns: Selected stuck threshold value
prompt_stuck_threshold() {
  local default="${1:-3}"

  echo ""
  read -rp "Stuck threshold (attempts before pausing) [$default]: " value

  # Use default if empty
  value="${value:-$default}"

  # Validate it's a positive integer
  if [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$value"
    return 0
  else
    warning "Invalid value, using default: $default"
    echo "$default"
    return 0
  fi
}

# Prompt for quality gates configuration
# Returns: JSON object with quality gate commands (via stdout)
prompt_quality_gates() {
  echo "" >&2
  echo "Configure quality gates (commands to run after each story):" >&2
  echo "" >&2

  # Read current defaults from ralph/config
  local current_typecheck=""
  local current_test=""
  local current_lint=""
  local current_build=""

  if [[ -f "ralph/config.yaml" ]]; then
    current_typecheck=$(yq -r '.defaults.quality_gates.typecheck // ""' ralph/config.yaml 2>/dev/null || echo "")
    current_test=$(yq -r '.defaults.quality_gates.test // ""' ralph/config.yaml 2>/dev/null || echo "")
    current_lint=$(yq -r '.defaults.quality_gates.lint // ""' ralph/config.yaml 2>/dev/null || echo "")
    current_build=$(yq -r '.defaults.quality_gates.build // ""' ralph/config.yaml 2>/dev/null || echo "")
  elif [[ -f "ralph/config.json" ]]; then
    current_typecheck=$(jq -r '.config.qualityGates.typecheck // ""' ralph/config.json 2>/dev/null || echo "")
    current_test=$(jq -r '.config.qualityGates.test // ""' ralph/config.json 2>/dev/null || echo "")
    current_lint=$(jq -r '.config.qualityGates.lint // ""' ralph/config.json 2>/dev/null || echo "")
    current_build=$(jq -r '.config.qualityGates.build // ""' ralph/config.json 2>/dev/null || echo "")

    # Handle "null" string values
    [[ "$current_typecheck" == "null" ]] && current_typecheck=""
    [[ "$current_test" == "null" ]] && current_test=""
    [[ "$current_lint" == "null" ]] && current_lint=""
    [[ "$current_build" == "null" ]] && current_build=""
  fi

  # Prompt for each gate
  local typecheck_cmd=""
  local test_cmd=""
  local lint_cmd=""
  local build_cmd=""

  # Typecheck gate
  if [[ -n "$current_typecheck" ]]; then
    read -rp "Typecheck command [$current_typecheck] (empty to disable): " typecheck_cmd
    typecheck_cmd="${typecheck_cmd:-$current_typecheck}"
  else
    read -rp "Typecheck command (empty to disable): " typecheck_cmd
  fi

  # Test gate
  if [[ -n "$current_test" ]]; then
    read -rp "Test command [$current_test] (empty to disable): " test_cmd
    test_cmd="${test_cmd:-$current_test}"
  else
    read -rp "Test command (empty to disable): " test_cmd
  fi

  # Lint gate
  if [[ -n "$current_lint" ]]; then
    read -rp "Lint command [$current_lint] (empty to disable): " lint_cmd
    lint_cmd="${lint_cmd:-$current_lint}"
  else
    read -rp "Lint command (empty to disable): " lint_cmd
  fi

  # Build gate
  if [[ -n "$current_build" ]]; then
    read -rp "Build command [$current_build] (empty to disable): " build_cmd
    build_cmd="${build_cmd:-$current_build}"
  else
    read -rp "Build command (empty to disable): " build_cmd
  fi

  # Convert to JSON format (null for empty, quoted string for values)
  local typecheck_json="null"
  local test_json="null"
  local lint_json="null"
  local build_json="null"

  [[ -n "$typecheck_cmd" ]] && typecheck_json="\"$typecheck_cmd\""
  [[ -n "$test_cmd" ]] && test_json="\"$test_cmd\""
  [[ -n "$lint_cmd" ]] && lint_json="\"$lint_cmd\""
  [[ -n "$build_cmd" ]] && build_json="\"$build_cmd\""

  # Output JSON object
  cat <<EOF
{
  "typecheck": $typecheck_json,
  "test": $test_json,
  "lint": $lint_json,
  "build": $build_json
}
EOF
}

# Display configuration summary
# Arguments:
#   $1: epic_filter - Epic filter (or empty for "all")
#   $2: max_iterations - Max iterations value
#   $3: stuck_threshold - Stuck threshold value
#   $4: quality_gates_json - Quality gates JSON string
display_config_summary() {
  local epic_filter="${1:-}"
  local max_iterations="$2"
  local stuck_threshold="$3"
  local quality_gates_json="$4"

  echo ""
  header "Configuration Summary"
  echo ""

  if [[ -n "$epic_filter" ]]; then
    local epic_name
    epic_name=$(get_epic_name "$epic_filter")
    echo "  Epic Filter: $epic_filter - $epic_name"
  else
    echo "  Epic Filter: All epics"
  fi

  echo "  Max Iterations: $max_iterations"
  echo "  Stuck Threshold: $stuck_threshold"
  echo ""
  echo "  Quality Gates:"

  # Parse and display quality gates
  local typecheck test lint build
  typecheck=$(echo "$quality_gates_json" | jq -r '.typecheck // "null"')
  test=$(echo "$quality_gates_json" | jq -r '.test // "null"')
  lint=$(echo "$quality_gates_json" | jq -r '.lint // "null"')
  build=$(echo "$quality_gates_json" | jq -r '.build // "null"')

  [[ "$typecheck" != "null" ]] && echo "    • Typecheck: $typecheck" || echo "    • Typecheck: disabled"
  [[ "$test" != "null" ]] && echo "    • Test: $test" || echo "    • Test: disabled"
  [[ "$lint" != "null" ]] && echo "    • Lint: $lint" || echo "    • Lint: disabled"
  [[ "$build" != "null" ]] && echo "    • Build: $build" || echo "    • Build: disabled"

  echo ""
}

# Get default quality gates from ralph config
# Returns: JSON object with default quality gate commands
get_default_quality_gates() {
  local typecheck_cmd=""
  local test_cmd=""
  local lint_cmd=""
  local build_cmd=""

  if [[ -f "ralph/config.yaml" ]]; then
    typecheck_cmd=$(yq -r '.defaults.quality_gates.typecheck // ""' ralph/config.yaml 2>/dev/null || echo "")
    test_cmd=$(yq -r '.defaults.quality_gates.test // ""' ralph/config.yaml 2>/dev/null || echo "")
    lint_cmd=$(yq -r '.defaults.quality_gates.lint // ""' ralph/config.yaml 2>/dev/null || echo "")
    build_cmd=$(yq -r '.defaults.quality_gates.build // ""' ralph/config.yaml 2>/dev/null || echo "")
  elif [[ -f "ralph/config.json" ]]; then
    typecheck_cmd=$(jq -r '.config.qualityGates.typecheck // ""' ralph/config.json 2>/dev/null || echo "")
    test_cmd=$(jq -r '.config.qualityGates.test // ""' ralph/config.json 2>/dev/null || echo "")
    lint_cmd=$(jq -r '.config.qualityGates.lint // ""' ralph/config.json 2>/dev/null || echo "")
    build_cmd=$(jq -r '.config.qualityGates.build // ""' ralph/config.json 2>/dev/null || echo "")

    # Handle "null" string values
    [[ "$typecheck_cmd" == "null" ]] && typecheck_cmd=""
    [[ "$test_cmd" == "null" ]] && test_cmd=""
    [[ "$lint_cmd" == "null" ]] && lint_cmd=""
    [[ "$build_cmd" == "null" ]] && build_cmd=""
  fi

  # Convert to JSON format (null for empty, quoted string for values)
  local typecheck_json="null"
  local test_json="null"
  local lint_json="null"
  local build_json="null"

  [[ -n "$typecheck_cmd" ]] && typecheck_json="\"$typecheck_cmd\""
  [[ -n "$test_cmd" ]] && test_json="\"$test_cmd\""
  [[ -n "$lint_cmd" ]] && lint_json="\"$lint_cmd\""
  [[ -n "$build_cmd" ]] && build_json="\"$build_cmd\""

  # Output JSON object
  cat <<EOF
{
  "typecheck": $typecheck_json,
  "test": $test_json,
  "lint": $lint_json,
  "build": $build_json
}
EOF
}
