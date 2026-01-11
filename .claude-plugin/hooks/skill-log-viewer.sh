#!/usr/bin/env bash
#
# Skill Invocation Log Viewer
# Utility for viewing and analyzing skill invocation logs
#
# Usage:
#   skill-log-viewer.sh [command] [options]
#
# Commands:
#   tail       Show recent invocations (default)
#   stats      Show invocation statistics
#   filter     Filter logs by level or skill
#   clear      Clear the log file
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

# Show recent log entries
show_tail() {
    local lines="${1:-20}"

    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}No skill invocation log found${NC}"
        return 0
    fi

    echo -e "${CYAN}Recent Skill Invocations (last $lines lines):${NC}"
    echo ""

    # Colorize log output
    tail -n "$lines" "$LOG_FILE" | while IFS= read -r line; do
        if [[ "$line" =~ \[ERROR\] ]]; then
            echo -e "${RED}${line}${NC}"
        elif [[ "$line" =~ \[WARN\] ]]; then
            echo -e "${YELLOW}${line}${NC}"
        elif [[ "$line" =~ \[SUCCESS\] ]]; then
            echo -e "${GREEN}${line}${NC}"
        elif [[ "$line" =~ \[INFO\] ]]; then
            echo -e "${BLUE}${line}${NC}"
        else
            echo "$line"
        fi
    done
}

# Show invocation statistics
show_stats() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}No skill invocation log found${NC}"
        return 0
    fi

    echo -e "${CYAN}Skill Invocation Statistics:${NC}"
    echo ""

    # Count total invocations
    local total_invocations=$(grep -c "Skill invoked:" "$LOG_FILE" 2>/dev/null || echo "0")
    echo -e "${GREEN}Total Invocations:${NC} $total_invocations"
    echo ""

    # Count by skill name
    echo -e "${CYAN}Invocations by Skill:${NC}"
    grep "Skill invoked:" "$LOG_FILE" 2>/dev/null | awk '{print $6}' | sort | uniq -c | while read count skill; do
        echo -e "  ${GREEN}${skill}${NC}: $count"
    done || echo "  None"
    echo ""

    # Count by trigger type
    echo -e "${CYAN}Invocations by Trigger:${NC}"
    grep "trigger:" "$LOG_FILE" 2>/dev/null | sed 's/.*trigger: \([^)]*\).*/\1/' | sort | uniq -c | while read count trigger; do
        echo -e "  ${GREEN}${trigger}${NC}: $count"
    done || echo "  None"
    echo ""

    # Count by log level
    echo -e "${CYAN}Log Entries by Level:${NC}"
    for level in INFO WARN ERROR SUCCESS; do
        local count=$(grep -c "\[$level\]" "$LOG_FILE" 2>/dev/null || echo "0")
        case "$level" in
            INFO) echo -e "  ${BLUE}INFO${NC}: $count" ;;
            WARN) echo -e "  ${YELLOW}WARN${NC}: $count" ;;
            ERROR) echo -e "  ${RED}ERROR${NC}: $count" ;;
            SUCCESS) echo -e "  ${GREEN}SUCCESS${NC}: $count" ;;
        esac
    done
    echo ""

    # Show time range
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        local first_entry=$(head -n 1 "$LOG_FILE" | grep -oP '\[.*?\]' | head -1 | tr -d '[]')
        local last_entry=$(tail -n 1 "$LOG_FILE" | grep -oP '\[.*?\]' | head -1 | tr -d '[]')
        echo -e "${CYAN}Log Time Range:${NC}"
        echo -e "  First: $first_entry"
        echo -e "  Last:  $last_entry"
        echo ""
    fi

    # Show log file size
    local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "0")
    echo -e "${CYAN}Log File Size:${NC} $log_size"
}

# Filter logs
filter_logs() {
    local filter_type="$1"
    local filter_value="$2"

    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}No skill invocation log found${NC}"
        return 0
    fi

    case "$filter_type" in
        level)
            echo -e "${CYAN}Log entries with level: $filter_value${NC}"
            echo ""
            grep "\[$filter_value\]" "$LOG_FILE" | while IFS= read -r line; do
                case "$filter_value" in
                    INFO) echo -e "${BLUE}${line}${NC}" ;;
                    WARN) echo -e "${YELLOW}${line}${NC}" ;;
                    ERROR) echo -e "${RED}${line}${NC}" ;;
                    SUCCESS) echo -e "${GREEN}${line}${NC}" ;;
                    *) echo "$line" ;;
                esac
            done
            ;;
        skill)
            echo -e "${CYAN}Log entries for skill: $filter_value${NC}"
            echo ""
            grep "$filter_value" "$LOG_FILE" | while IFS= read -r line; do
                if [[ "$line" =~ \[ERROR\] ]]; then
                    echo -e "${RED}${line}${NC}"
                elif [[ "$line" =~ \[WARN\] ]]; then
                    echo -e "${YELLOW}${line}${NC}"
                elif [[ "$line" =~ \[SUCCESS\] ]]; then
                    echo -e "${GREEN}${line}${NC}"
                elif [[ "$line" =~ \[INFO\] ]]; then
                    echo -e "${BLUE}${line}${NC}"
                else
                    echo "$line"
                fi
            done
            ;;
        *)
            echo -e "${RED}Unknown filter type: $filter_type${NC}"
            echo "Usage: $0 filter [level|skill] <value>"
            return 1
            ;;
    esac
}

# Clear log file
clear_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}No skill invocation log found${NC}"
        return 0
    fi

    # Prompt for confirmation
    echo -e "${YELLOW}Are you sure you want to clear the skill invocation log?${NC}"
    echo -e "${YELLOW}This cannot be undone.${NC}"
    read -p "Type 'yes' to confirm: " confirmation

    if [ "$confirmation" = "yes" ]; then
        > "$LOG_FILE"
        echo -e "${GREEN}Log file cleared${NC}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
    fi
}

# Show usage
show_usage() {
    echo "Skill Invocation Log Viewer"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  tail [lines]           Show recent invocations (default: 20 lines)"
    echo "  stats                  Show invocation statistics"
    echo "  filter level <level>   Filter logs by level (INFO, WARN, ERROR, SUCCESS)"
    echo "  filter skill <name>    Filter logs by skill name"
    echo "  clear                  Clear the log file"
    echo "  help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 tail 50"
    echo "  $0 stats"
    echo "  $0 filter level ERROR"
    echo "  $0 filter skill loop-optimization"
    echo "  $0 clear"
}

# Main execution logic
main() {
    local command="${1:-tail}"

    case "$command" in
        tail)
            show_tail "${2:-20}"
            ;;
        stats)
            show_stats
            ;;
        filter)
            if [ $# -lt 3 ]; then
                echo -e "${RED}Error: filter command requires type and value${NC}"
                echo "Usage: $0 filter [level|skill] <value>"
                return 1
            fi
            filter_logs "$2" "$3"
            ;;
        clear)
            clear_logs
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo ""
            show_usage
            return 1
            ;;
    esac

    return 0
}

# Run main function
main "$@"
