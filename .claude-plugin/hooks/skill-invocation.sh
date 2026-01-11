#!/usr/bin/env bash
#
# Skill Invocation Hook
# Handles skill auto-invocation based on context detection and trigger conditions
#
# This hook is called at various points during loop execution to determine
# if skills should be invoked based on current context and trigger conditions.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the plugin root directory
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_DIR/.." && pwd)"

# Logging configuration
LOG_DIR="$PROJECT_ROOT/ralph/logs"
LOG_FILE="$LOG_DIR/skill-invocations.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log_invocation() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"

    # Also output to console for visibility
    case "$level" in
        INFO)
            echo -e "${BLUE}[SKILL]${NC} ${message}"
            ;;
        WARN)
            echo -e "${YELLOW}[SKILL]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[SKILL]${NC} ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SKILL]${NC} ${message}"
            ;;
    esac
}

# Check if a file exists (for lock file detection)
check_file_exists() {
    local pattern="$1"

    # Use shell glob to find matching files
    shopt -s nullglob
    local files=($pattern)
    shopt -u nullglob

    if [ ${#files[@]} -gt 0 ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}

# Get JSON value from config file
get_json_value() {
    local pattern="$1"
    local key="$2"

    # Find matching config files
    shopt -s nullglob
    local files=($pattern)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        echo "0"
        return
    fi

    # Use the first matching file
    local file="${files[0]}"

    # Extract value using jq
    if command -v jq &> /dev/null; then
        local value=$(jq -r "$key // 0" "$file" 2>/dev/null || echo "0")
        echo "$value"
    else
        echo "0"
    fi
}

# Parse file for pattern (for quality gate status)
parse_file_pattern() {
    local pattern="$1"
    local search_pattern="$2"

    # Find matching files
    shopt -s nullglob
    local files=($pattern)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        echo "unknown"
        return
    fi

    # Use the first matching file
    local file="${files[0]}"

    # Search for pattern in file
    if [ -f "$file" ]; then
        grep -oP "$search_pattern" "$file" | tail -1 || echo "unknown"
    else
        echo "unknown"
    fi
}

# Detect current context
detect_context() {
    local context="$1"

    case "$context" in
        loop_running)
            check_file_exists "$PROJECT_ROOT/ralph/loops/*/.lock"
            return $?
            ;;
        iteration_count)
            local count=$(get_json_value "$PROJECT_ROOT/ralph/loops/*/config.json" ".stats.iterationsRun")
            echo "$count"
            ;;
        quality_gate_status)
            local status=$(parse_file_pattern "$PROJECT_ROOT/ralph/loops/*/progress.txt" "Quality gates: (.*)")
            echo "$status"
            ;;
        *)
            log_invocation "WARN" "Unknown context: $context"
            return 1
            ;;
    esac
}

# Check if skill should be invoked based on triggers
should_invoke_skill() {
    local skill_name="$1"
    local trigger_type="$2"

    # Read skill metadata from SKILL.md
    local skill_dir="$PLUGIN_DIR/skills/$skill_name"
    local skill_file="$skill_dir/SKILL.md"

    if [ ! -f "$skill_file" ]; then
        log_invocation "WARN" "Skill file not found: $skill_file"
        return 1
    fi

    # Parse YAML frontmatter for auto_invoke setting
    local auto_invoke=$(grep -A 20 "^---" "$skill_file" | grep "auto_invoke:" | awk '{print $2}' || echo "false")

    if [ "$auto_invoke" != "true" ]; then
        return 1  # Skill does not have auto_invoke enabled
    fi

    # Check context conditions
    case "$trigger_type" in
        story_completion)
            # Check if loop is running
            if detect_context "loop_running"; then
                local iteration_count=$(detect_context "iteration_count")
                if [ "$iteration_count" -gt 0 ]; then
                    return 0  # Should invoke
                fi
            fi
            ;;
        iteration_milestone)
            local iteration_count=$(detect_context "iteration_count")
            local interval=5  # Every 5 iterations
            if [ $((iteration_count % interval)) -eq 0 ] && [ "$iteration_count" -gt 0 ]; then
                return 0  # Should invoke
            fi
            ;;
        quality_gate_failure)
            local status=$(detect_context "quality_gate_status")
            if [[ "$status" =~ "failed" ]] || [[ "$status" =~ "FAILED" ]]; then
                return 0  # Should invoke
            fi
            ;;
    esac

    return 1  # Should not invoke
}

# Find all skills in the skills directory
find_skills() {
    local skills_dir="$PLUGIN_DIR/skills"

    if [ ! -d "$skills_dir" ]; then
        log_invocation "WARN" "Skills directory not found: $skills_dir"
        return
    fi

    # List all skill directories that contain SKILL.md
    find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
}

# Invoke a skill
invoke_skill() {
    local skill_name="$1"
    local trigger_type="$2"

    log_invocation "INFO" "Invoking skill: $skill_name (trigger: $trigger_type)"

    # In a real implementation, this would invoke the skill through Claude Code's API
    # For now, we just log the invocation

    # Get context information
    local iteration_count=$(detect_context "iteration_count" 2>/dev/null || echo "0")
    local quality_gate_status=$(detect_context "quality_gate_status" 2>/dev/null || echo "unknown")

    log_invocation "SUCCESS" "Skill invoked: $skill_name"
    log_invocation "INFO" "  Context: iteration_count=$iteration_count, quality_gate_status=$quality_gate_status"

    return 0
}

# Main execution logic
main() {
    local trigger_type="${1:-story_completion}"

    log_invocation "INFO" "Checking for skills to invoke (trigger: $trigger_type)"

    # Find all skills
    local skills=($(find_skills))

    if [ ${#skills[@]} -eq 0 ]; then
        log_invocation "INFO" "No skills found"
        return 0
    fi

    log_invocation "INFO" "Found ${#skills[@]} skill(s): ${skills[*]}"

    # Check each skill to see if it should be invoked
    local invoked_count=0
    for skill in "${skills[@]}"; do
        if should_invoke_skill "$skill" "$trigger_type"; then
            invoke_skill "$skill" "$trigger_type"
            ((invoked_count++))

            # Prevent infinite chaining - max 3 skills per trigger
            if [ $invoked_count -ge 3 ]; then
                log_invocation "WARN" "Max skill chain depth reached (3), stopping invocation"
                break
            fi
        fi
    done

    if [ $invoked_count -eq 0 ]; then
        log_invocation "INFO" "No skills matched trigger conditions"
    else
        log_invocation "SUCCESS" "Invoked $invoked_count skill(s)"
    fi

    return 0
}

# Run main function (don't fail hook on error)
main "$@" || {
    log_invocation "ERROR" "Skill invocation check failed: $?"
    exit 0  # Don't block hook execution
}
