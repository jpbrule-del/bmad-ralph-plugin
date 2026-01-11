#!/usr/bin/env bash
# Output utilities for colored terminal output

# Guard against multiple sourcing
[[ -n "${_OUTPUT_SH_SOURCED:-}" ]] && return 0
readonly _OUTPUT_SH_SOURCED=1

# Color codes (respect NO_COLOR environment variable)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  readonly COLOR_RED='\033[0;31m'
  readonly COLOR_GREEN='\033[0;32m'
  readonly COLOR_YELLOW='\033[0;33m'
  readonly COLOR_BLUE='\033[0;34m'
  readonly COLOR_CYAN='\033[0;36m'
  readonly COLOR_DIM='\033[2m'
  readonly COLOR_RESET='\033[0m'
else
  readonly COLOR_RED=''
  readonly COLOR_GREEN=''
  readonly COLOR_YELLOW=''
  readonly COLOR_BLUE=''
  readonly COLOR_CYAN=''
  readonly COLOR_DIM=''
  readonly COLOR_RESET=''
fi

# Print functions
info() {
  echo -e "${COLOR_BLUE}→${COLOR_RESET} $*"
}

success() {
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"
}

warning() {
  echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $*"
}

error() {
  echo -e "${COLOR_RED}✗${COLOR_RESET} $*" >&2
}

header() {
  echo -e "${COLOR_CYAN}$*${COLOR_RESET}"
}

section() {
  echo -e "${COLOR_BLUE}## $*${COLOR_RESET}"
}

warn() {
  warning "$@"
}

# Colorize text with a named color
# Arguments:
#   $1: text - The text to colorize
#   $2: color - Color name (green, red, yellow, blue, cyan, dim)
colorize() {
  local text="$1"
  local color="${2:-}"

  case "$color" in
    green)  echo -e "${COLOR_GREEN}${text}${COLOR_RESET}" ;;
    red)    echo -e "${COLOR_RED}${text}${COLOR_RESET}" ;;
    yellow) echo -e "${COLOR_YELLOW}${text}${COLOR_RESET}" ;;
    blue)   echo -e "${COLOR_BLUE}${text}${COLOR_RESET}" ;;
    cyan)   echo -e "${COLOR_CYAN}${text}${COLOR_RESET}" ;;
    dim)    echo -e "${COLOR_DIM}${text}${COLOR_RESET}" ;;
    *)      echo "$text" ;;
  esac
}
