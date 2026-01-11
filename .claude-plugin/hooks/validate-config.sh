#!/usr/bin/env bash
# validate-config.sh - Validate Ralph plugin configuration
# This script loads default config from plugin.json, merges with project-level
# overrides from ralph/config.yaml, and validates the final configuration.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the plugin directory (parent of hooks/)
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_JSON="${PLUGIN_DIR}/plugin.json"

# Function to print error message
error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Function to print warning message
warning() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

# Function to print success message
success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

# Function to validate integer range
validate_integer_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local name="$4"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        error "${name} must be an integer, got: ${value}"
        return 1
    fi

    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        error "${name} must be between ${min} and ${max}, got: ${value}"
        return 1
    fi

    return 0
}

# Check if plugin.json exists
if [ ! -f "$PLUGIN_JSON" ]; then
    error "Plugin manifest not found: ${PLUGIN_JSON}"
    exit 1
fi

# Load default configuration from plugin.json
if ! DEFAULTS=$(jq -r '.config.defaults' "$PLUGIN_JSON" 2>/dev/null); then
    error "Failed to read default configuration from plugin.json"
    exit 1
fi

if [ "$DEFAULTS" = "null" ]; then
    error "No default configuration found in plugin.json"
    exit 1
fi

# Extract default values
MAX_ITERATIONS=$(echo "$DEFAULTS" | jq -r '.max_iterations')
STUCK_THRESHOLD=$(echo "$DEFAULTS" | jq -r '.stuck_threshold')

# Check for project-level overrides
OVERRIDE_PATH=$(jq -r '.config.override_path' "$PLUGIN_JSON")
PROJECT_CONFIG="${PWD}/${OVERRIDE_PATH}"

# Initialize with defaults
FINAL_MAX_ITERATIONS="$MAX_ITERATIONS"
FINAL_STUCK_THRESHOLD="$STUCK_THRESHOLD"

# If project config exists, merge overrides
if [ -f "$PROJECT_CONFIG" ]; then
    success "Found project configuration: ${PROJECT_CONFIG}"

    # Try to read overrides
    if OVERRIDE_MAX_ITERATIONS=$(yq eval '.max_iterations // "null"' "$PROJECT_CONFIG" 2>/dev/null); then
        if [ "$OVERRIDE_MAX_ITERATIONS" != "null" ]; then
            FINAL_MAX_ITERATIONS="$OVERRIDE_MAX_ITERATIONS"
            success "Override: max_iterations = ${FINAL_MAX_ITERATIONS}"
        fi
    fi

    if OVERRIDE_STUCK_THRESHOLD=$(yq eval '.stuck_threshold // "null"' "$PROJECT_CONFIG" 2>/dev/null); then
        if [ "$OVERRIDE_STUCK_THRESHOLD" != "null" ]; then
            FINAL_STUCK_THRESHOLD="$OVERRIDE_STUCK_THRESHOLD"
            success "Override: stuck_threshold = ${FINAL_STUCK_THRESHOLD}"
        fi
    fi
else
    success "No project configuration found, using defaults"
fi

# Validate final configuration
success "Validating configuration..."

# Validate max_iterations (1-1000)
if ! validate_integer_range "$FINAL_MAX_ITERATIONS" 1 1000 "max_iterations"; then
    exit 1
fi

# Validate stuck_threshold (1-10)
if ! validate_integer_range "$FINAL_STUCK_THRESHOLD" 1 10 "stuck_threshold"; then
    exit 1
fi

# Validate quality gates
QUALITY_GATES=$(echo "$DEFAULTS" | jq -r '.quality_gates')
if [ "$QUALITY_GATES" = "null" ]; then
    warning "No quality gates defined in configuration"
else
    # Check if quality gate commands are defined
    LINT_CMD=$(echo "$QUALITY_GATES" | jq -r '.lint // "null"')
    BUILD_CMD=$(echo "$QUALITY_GATES" | jq -r '.build // "null"')

    if [ "$LINT_CMD" = "null" ] && [ "$BUILD_CMD" = "null" ]; then
        warning "No quality gate commands defined"
    else
        success "Quality gates configured"
    fi
fi

success "Configuration validation passed"
success "  max_iterations: ${FINAL_MAX_ITERATIONS}"
success "  stuck_threshold: ${FINAL_STUCK_THRESHOLD}"

exit 0
