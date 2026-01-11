#!/usr/bin/env bash
# Dependency validation for ralph CLI
# Checks for required dependencies and provides installation instructions

# Check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Get package manager installation command
get_install_cmd() {
  local package="$1"
  local brew_name="${2:-$package}"
  local apt_name="${3:-$package}"

  if command_exists brew; then
    echo "brew install $brew_name"
  elif command_exists apt-get; then
    echo "sudo apt-get install $apt_name"
  else
    echo "Please install $package manually"
  fi
}

# Check for jq
check_jq() {
  if ! command_exists jq; then
    error "Missing dependency: jq"
    echo "  jq is required for JSON processing"
    echo "  Install: $(get_install_cmd jq)"
    return 1
  fi
  return 0
}

# Check for yq
check_yq() {
  if ! command_exists yq; then
    error "Missing dependency: yq"
    echo "  yq is required for YAML processing"
    echo "  Install: $(get_install_cmd yq)"
    return 1
  fi

  # Version check for yq (need v4.x)
  local yq_version
  yq_version=$(yq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  local major_version
  major_version=$(echo "$yq_version" | cut -d. -f1)

  if [[ -n "$major_version" ]] && [[ "$major_version" -lt 4 ]]; then
    warning "yq version $yq_version detected (v4.x recommended)"
    echo "  Consider upgrading: $(get_install_cmd yq)"
  fi

  return 0
}

# Check for git
check_git() {
  if ! command_exists git; then
    error "Missing dependency: git"
    echo "  git is required for version control operations"
    echo "  Install: $(get_install_cmd git)"
    return 1
  fi

  # Version check for git (need 2.x+)
  local git_version
  git_version=$(git --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  local major_version
  major_version=$(echo "$git_version" | cut -d. -f1)

  if [[ -n "$major_version" ]] && [[ "$major_version" -lt 2 ]]; then
    warning "git version $git_version detected (v2.x+ recommended)"
    echo "  Consider upgrading: $(get_install_cmd git)"
  fi

  return 0
}

# Check for claude CLI
check_claude() {
  if ! command_exists claude; then
    error "Missing dependency: claude"
    echo "  Claude Code CLI is required for autonomous execution"
    echo "  Install: npm install -g @anthropic-ai/claude-code"
    return 1
  fi
  return 0
}

# Main dependency validation function
validate_dependencies() {
  local all_present=true

  # Check each dependency
  check_jq || all_present=false
  check_yq || all_present=false
  check_git || all_present=false
  check_claude || all_present=false

  if [[ "$all_present" == false ]]; then
    echo ""
    error "Please install missing dependencies and try again"
    return 1
  fi

  return 0
}
