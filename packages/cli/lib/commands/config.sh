#!/usr/bin/env bash
# ralph config - Manage ralph configuration

# Source interactive utilities
readonly CONFIG_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"
source "$CONFIG_LIB_DIR/core/interactive.sh"

cmd_config() {
  local subcommand="${1:-}"

  # Require subcommand
  if [[ -z "$subcommand" ]]; then
    error "Subcommand required"
    echo ""
    echo "Usage: ralph config <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  show           Display current configuration"
    echo "  quality-gates  Configure quality gates interactively"
    echo ""
    echo "Examples:"
    echo "  ralph config show"
    echo "  ralph config quality-gates"
    exit 1
  fi

  # Check if ralph is initialized
  if [[ ! -f "ralph/config.yaml" ]] && [[ ! -f "ralph/config.json" ]]; then
    error "Ralph is not initialized in this project"
    echo ""
    echo "Run 'ralph init' first to initialize ralph"
    exit 1
  fi

  shift

  case "$subcommand" in
    show)
      cmd_config_show "$@"
      ;;
    quality-gates)
      cmd_config_quality_gates "$@"
      ;;
    *)
      error "Unknown subcommand: $subcommand"
      echo ""
      echo "Available subcommands: show, quality-gates"
      exit 1
      ;;
  esac
}

# Show current configuration
cmd_config_show() {
  header "Ralph Configuration"
  echo ""

  # Determine config file
  local config_file=""
  if [[ -f "ralph/config.json" ]]; then
    config_file="ralph/config.json"
  elif [[ -f "ralph/config.yaml" ]]; then
    config_file="ralph/config.yaml"
  fi

  if [[ -z "$config_file" ]]; then
    error "No configuration file found"
    exit 1
  fi

  info "Configuration file: $config_file"
  echo ""

  # Display quality gates
  echo "Quality Gates:"
  echo ""

  local typecheck test lint build
  if [[ "$config_file" == "ralph/config.json" ]]; then
    typecheck=$(jq -r '.config.qualityGates.typecheck // "null"' "$config_file" 2>/dev/null || echo "null")
    test=$(jq -r '.config.qualityGates.test // "null"' "$config_file" 2>/dev/null || echo "null")
    lint=$(jq -r '.config.qualityGates.lint // "null"' "$config_file" 2>/dev/null || echo "null")
    build=$(jq -r '.config.qualityGates.build // "null"' "$config_file" 2>/dev/null || echo "null")
  else
    typecheck=$(yq -r '.qualityGates.typecheck // "null"' "$config_file" 2>/dev/null || echo "null")
    test=$(yq -r '.qualityGates.test // "null"' "$config_file" 2>/dev/null || echo "null")
    lint=$(yq -r '.qualityGates.lint // "null"' "$config_file" 2>/dev/null || echo "null")
    build=$(yq -r '.qualityGates.build // "null"' "$config_file" 2>/dev/null || echo "null")
  fi

  # Display with status indicators
  if [[ "$typecheck" != "null" ]]; then
    echo "  • Typecheck: $(colorize "$typecheck" "green")"
  else
    echo "  • Typecheck: $(colorize "disabled" "dim")"
  fi

  if [[ "$test" != "null" ]]; then
    echo "  • Test: $(colorize "$test" "green")"
  else
    echo "  • Test: $(colorize "disabled" "dim")"
  fi

  if [[ "$lint" != "null" ]]; then
    echo "  • Lint: $(colorize "$lint" "green")"
  else
    echo "  • Lint: $(colorize "disabled" "dim")"
  fi

  if [[ "$build" != "null" ]]; then
    echo "  • Build: $(colorize "$build" "green")"
  else
    echo "  • Build: $(colorize "disabled" "dim")"
  fi

  echo ""
  echo "To modify configuration, run: ralph config quality-gates"
  echo ""
}

# Configure quality gates interactively
cmd_config_quality_gates() {
  header "Configure Quality Gates"
  echo ""

  info "Quality gates run after each story implementation"
  echo ""

  # Use prompt_quality_gates from interactive.sh
  local quality_gates_json
  quality_gates_json=$(prompt_quality_gates)

  # Display configuration summary
  echo ""
  header "New Configuration"
  echo ""

  local typecheck test lint build
  typecheck=$(echo "$quality_gates_json" | jq -r '.typecheck // "null"')
  test=$(echo "$quality_gates_json" | jq -r '.test // "null"')
  lint=$(echo "$quality_gates_json" | jq -r '.lint // "null"')
  build=$(echo "$quality_gates_json" | jq -r '.build // "null"')

  if [[ "$typecheck" != "null" ]]; then
    echo "  • Typecheck: $typecheck"
  else
    echo "  • Typecheck: disabled"
  fi

  if [[ "$test" != "null" ]]; then
    echo "  • Test: $test"
  else
    echo "  • Test: disabled"
  fi

  if [[ "$lint" != "null" ]]; then
    echo "  • Lint: $lint"
  else
    echo "  • Lint: disabled"
  fi

  if [[ "$build" != "null" ]]; then
    echo "  • Build: $build"
  else
    echo "  • Build: disabled"
  fi

  echo ""

  # Confirm changes
  read -rp "Save this configuration? [Y/n]: " confirm
  confirm="${confirm:-Y}"

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warning "Configuration not saved"
    exit 0
  fi

  # Update configuration file
  if [[ -f "ralph/config.json" ]]; then
    info "Updating ralph/config.json..."

    # Use atomic write pattern
    local temp_file
    temp_file=$(mktemp)

    jq --arg typecheck "$typecheck" \
       --arg test "$test" \
       --arg lint "$lint" \
       --arg build "$build" \
       '.config.qualityGates.typecheck = (if $typecheck == "null" then null else $typecheck end) |
        .config.qualityGates.test = (if $test == "null" then null else $test end) |
        .config.qualityGates.lint = (if $lint == "null" then null else $lint end) |
        .config.qualityGates.build = (if $build == "null" then null else $build end)' \
       ralph/config.json > "$temp_file"

    if jq . "$temp_file" >/dev/null 2>&1; then
      mv "$temp_file" ralph/config.json
      success "Quality gates configuration saved"
    else
      rm -f "$temp_file"
      error "Failed to update configuration"
      exit 1
    fi
  elif [[ -f "ralph/config.yaml" ]]; then
    info "Updating ralph/config.yaml..."

    # Use atomic write pattern
    local temp_file
    temp_file=$(mktemp)

    # Build yq update commands
    local yq_cmd="yq"

    if [[ "$typecheck" != "null" ]]; then
      yq_cmd="$yq_cmd '.qualityGates.typecheck = \"$typecheck\"'"
    else
      yq_cmd="$yq_cmd 'del(.qualityGates.typecheck)'"
    fi

    if [[ "$test" != "null" ]]; then
      yq_cmd="$yq_cmd ' | .qualityGates.test = \"$test\"'"
    else
      yq_cmd="$yq_cmd ' | del(.qualityGates.test)'"
    fi

    if [[ "$lint" != "null" ]]; then
      yq_cmd="$yq_cmd ' | .qualityGates.lint = \"$lint\"'"
    else
      yq_cmd="$yq_cmd ' | del(.qualityGates.lint)'"
    fi

    if [[ "$build" != "null" ]]; then
      yq_cmd="$yq_cmd ' | .qualityGates.build = \"$build\"'"
    else
      yq_cmd="$yq_cmd ' | del(.qualityGates.build)'"
    fi

    # Execute yq command
    eval "$yq_cmd ralph/config.yaml" > "$temp_file"

    if yq . "$temp_file" >/dev/null 2>&1; then
      mv "$temp_file" ralph/config.yaml
      success "Quality gates configuration saved"
    else
      rm -f "$temp_file"
      error "Failed to update configuration"
      exit 1
    fi
  else
    error "No configuration file found"
    exit 1
  fi

  echo ""
  info "Quality gates will be used for new loops created after this change"
  echo ""
}
