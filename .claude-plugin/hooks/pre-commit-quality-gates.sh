#!/usr/bin/env bash
#
# Pre-Commit Quality Gates Hook
# STORY-024: Implement Pre-Commit Hook
#
# This hook runs quality gates before git commits to ensure code quality standards are met.
# It can be bypassed in emergencies using the RALPH_BYPASS_HOOKS environment variable.
#
# Exit codes:
#   0 - All quality gates passed
#   1 - One or more quality gates failed
#   2 - Configuration error

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Log file path
LOG_DIR="${PROJECT_ROOT}/.ralph-cache"
LOG_FILE="${LOG_DIR}/hooks.log"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "[${timestamp}] [${level}] pre-commit-quality-gates: ${message}" >> "${LOG_FILE}"
}

# Print with color
print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

# Print section header
print_header() {
    echo ""
    print_color "${BLUE}" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "${BLUE}" "$1"
    print_color "${BLUE}" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check for bypass flag
check_bypass() {
    if [[ -n "${RALPH_BYPASS_HOOKS:-}" ]]; then
        print_color "${YELLOW}" "⚠️  BYPASS: RALPH_BYPASS_HOOKS is set - skipping quality gates"
        log "WARN" "Quality gates bypassed via RALPH_BYPASS_HOOKS environment variable"
        return 0
    fi
    return 1
}

# Detect if we're in a Ralph loop context
detect_loop_context() {
    # Check if we're in a ralph loop directory
    if [[ -f "${PROJECT_ROOT}/ralph/loops/config.json" ]] || \
       [[ -d "${PROJECT_ROOT}/ralph/loops" ]]; then
        # Try to find the current loop from git branch
        local current_branch
        current_branch="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

        if [[ "${current_branch}" =~ ^ralph/(.+)$ ]]; then
            local loop_name="${BASH_REMATCH[1]}"
            local loop_config="${PROJECT_ROOT}/ralph/loops/${loop_name}/config.json"

            if [[ -f "${loop_config}" ]]; then
                echo "${loop_config}"
                return 0
            fi
        fi
    fi

    # Not in a loop context
    echo ""
    return 0
}

# Load quality gates configuration
load_quality_gates() {
    local loop_config="$1"

    # Try to load from loop config if available
    if [[ -n "${loop_config}" ]] && [[ -f "${loop_config}" ]]; then
        if command -v jq >/dev/null 2>&1; then
            local gates
            gates="$(jq -r '.config.qualityGates // {}' "${loop_config}" 2>/dev/null || echo "{}")"
            if [[ "${gates}" != "{}" ]] && [[ "${gates}" != "null" ]]; then
                echo "${gates}"
                log "INFO" "Loaded quality gates from loop config: ${loop_config}"
                return 0
            fi
        fi
    fi

    # Fallback to default quality gates
    local default_gates='{
  "lint": "npm run lint",
  "build": "npm run build"
}'
    echo "${default_gates}"
    log "INFO" "Using default quality gates (lint, build)"
    return 0
}

# Run a single quality gate
run_quality_gate() {
    local gate_name="$1"
    local gate_command="$2"

    print_color "${BLUE}" "  Running ${gate_name}..."
    log "INFO" "Running quality gate: ${gate_name} (${gate_command})"

    # Create a temporary file for output
    local output_file
    output_file="$(mktemp)"

    # Run the command and capture output
    local exit_code=0
    if eval "cd '${PROJECT_ROOT}' && ${gate_command}" > "${output_file}" 2>&1; then
        print_color "${GREEN}" "  ✓ ${gate_name} passed"
        log "INFO" "Quality gate passed: ${gate_name}"
        rm -f "${output_file}"
        return 0
    else
        exit_code=$?
        print_color "${RED}" "  ✗ ${gate_name} failed (exit code: ${exit_code})"
        log "ERROR" "Quality gate failed: ${gate_name} (exit code: ${exit_code})"

        # Show relevant error output (last 20 lines)
        echo ""
        print_color "${RED}" "  Error output (last 20 lines):"
        tail -n 20 "${output_file}" | sed 's/^/    /'
        echo ""

        rm -f "${output_file}"
        return 1
    fi
}

# Main execution
main() {
    log "INFO" "Pre-commit hook started"

    print_header "🔒 Pre-Commit Quality Gates"

    # Check for bypass
    if check_bypass; then
        exit 0
    fi

    # Detect loop context
    local loop_config
    loop_config="$(detect_loop_context)"

    if [[ -n "${loop_config}" ]]; then
        print_color "${BLUE}" "📍 Loop context detected: $(basename "$(dirname "${loop_config}")")"
        log "INFO" "Loop context: ${loop_config}"
    else
        print_color "${BLUE}" "📍 Running in global context"
        log "INFO" "No loop context detected, using global configuration"
    fi

    # Load quality gates
    local quality_gates
    quality_gates="$(load_quality_gates "${loop_config}")"

    if [[ -z "${quality_gates}" ]] || [[ "${quality_gates}" == "null" ]] || [[ "${quality_gates}" == "{}" ]]; then
        print_color "${YELLOW}" "⚠️  No quality gates configured - skipping validation"
        log "WARN" "No quality gates configured"
        exit 0
    fi

    # Parse and run each quality gate
    local failed=0
    local total=0
    local failed_gates=()

    if command -v jq >/dev/null 2>&1; then
        echo ""
        print_color "${BLUE}" "Running quality gates..."

        while IFS= read -r line; do
            if [[ -z "${line}" ]]; then
                continue
            fi

            local gate_name gate_command
            gate_name="$(echo "${line}" | cut -d'|' -f1)"
            gate_command="$(echo "${line}" | cut -d'|' -f2)"

            # Skip if command is null or empty
            if [[ "${gate_command}" == "null" ]] || [[ -z "${gate_command}" ]]; then
                continue
            fi

            total=$((total + 1))

            if ! run_quality_gate "${gate_name}" "${gate_command}"; then
                failed=$((failed + 1))
                failed_gates+=("${gate_name}")
            fi
        done < <(echo "${quality_gates}" | jq -r 'to_entries[] | "\(.key)|\(.value)"')
    else
        print_color "${RED}" "✗ Error: jq is not installed - cannot parse quality gates"
        log "ERROR" "jq is not installed"
        exit 2
    fi

    # Summary
    echo ""
    print_header "📊 Quality Gates Summary"

    if [[ ${failed} -eq 0 ]]; then
        print_color "${GREEN}" "✓ All quality gates passed (${total}/${total})"
        log "INFO" "All quality gates passed (${total}/${total})"
        echo ""
        print_color "${GREEN}" "✓ Commit allowed"
        exit 0
    else
        local passed=$((total - failed))
        print_color "${RED}" "✗ Quality gates failed: ${failed}/${total}"
        print_color "${GREEN}" "  Passed: ${passed}"
        print_color "${RED}" "  Failed: ${failed}"

        echo ""
        print_color "${RED}" "Failed gates:"
        for gate in "${failed_gates[@]}"; do
            print_color "${RED}" "  • ${gate}"
        done

        echo ""
        print_color "${RED}" "✗ Commit blocked"
        echo ""
        print_color "${YELLOW}" "To fix:"
        print_color "${YELLOW}" "  1. Fix the failing quality gates above"
        print_color "${YELLOW}" "  2. Stage your fixes: git add <files>"
        print_color "${YELLOW}" "  3. Try committing again"
        echo ""
        print_color "${YELLOW}" "Emergency bypass (use with caution):"
        print_color "${YELLOW}" "  RALPH_BYPASS_HOOKS=1 git commit ..."

        log "ERROR" "Commit blocked - quality gates failed (${failed}/${total})"
        exit 1
    fi
}

# Run main function
main "$@"
