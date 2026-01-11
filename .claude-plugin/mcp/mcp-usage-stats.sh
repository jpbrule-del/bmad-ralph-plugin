#!/usr/bin/env bash
# MCP Usage Statistics - Analyze MCP usage logs
# Part of BMAD Ralph Plugin - STORY-030

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_DIR="ralph/logs"
LOG_FILE="$LOG_DIR/mcp-usage.log"

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  MCP Usage Statistics${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_log_exists() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}⚠ No usage log found at $LOG_FILE${NC}"
        echo ""
        echo "This is normal if MCP hasn't been used yet."
        echo "Usage will be logged when the Ralph agent uses MCP capabilities."
        return 1
    fi
    return 0
}

show_summary() {
    echo -e "${CYAN}Summary Statistics${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

    local total_requests=$(wc -l < "$LOG_FILE" | tr -d ' ')
    echo "  Total Requests: $total_requests"

    if [[ $total_requests -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}No MCP requests logged yet.${NC}"
        return 0
    fi

    # Count by request type
    local search_count=$(grep -c "type.*search" "$LOG_FILE" 2>/dev/null || echo "0")
    local research_count=$(grep -c "type.*research" "$LOG_FILE" 2>/dev/null || echo "0")
    local ask_count=$(grep -c "type.*ask" "$LOG_FILE" 2>/dev/null || echo "0")

    echo "  - Search: $search_count"
    echo "  - Research: $research_count"
    echo "  - Ask: $ask_count"

    # Count successes and failures
    local success_count=$(grep -c "status.*success" "$LOG_FILE" 2>/dev/null || echo "0")
    local error_count=$(grep -c "status.*error\|status.*failed" "$LOG_FILE" 2>/dev/null || echo "0")

    echo ""
    echo "  Successes: ${GREEN}$success_count${NC}"
    echo "  Errors: ${RED}$error_count${NC}"

    # Calculate success rate
    if [[ $total_requests -gt 0 ]]; then
        local success_rate=$(awk "BEGIN {printf \"%.1f\", ($success_count / $total_requests) * 100}")
        echo "  Success Rate: ${success_rate}%"
    fi

    echo ""
}

show_recent_activity() {
    echo -e "${CYAN}Recent Activity (Last 10 Requests)${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

    if ! check_log_exists; then
        return 0
    fi

    # Show last 10 lines with basic formatting
    tail -10 "$LOG_FILE" | while IFS= read -r line; do
        if [[ "$line" =~ "success" ]]; then
            echo -e "  ${GREEN}•${NC} $line"
        elif [[ "$line" =~ "error" || "$line" =~ "failed" ]]; then
            echo -e "  ${RED}✗${NC} $line"
        else
            echo -e "  ${BLUE}•${NC} $line"
        fi
    done

    echo ""
}

show_error_details() {
    echo -e "${CYAN}Error Analysis${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

    if ! check_log_exists; then
        return 0
    fi

    local error_count=$(grep -c "error\|failed" "$LOG_FILE" 2>/dev/null || echo "0")

    if [[ $error_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓ No errors found${NC}"
        echo ""
        return 0
    fi

    echo "  Total Errors: ${RED}$error_count${NC}"
    echo ""
    echo "  Recent Errors:"

    # Show last 5 errors
    grep -i "error\|failed" "$LOG_FILE" | tail -5 | while IFS= read -r line; do
        echo -e "    ${RED}✗${NC} $line"
    done

    echo ""

    # Count error types
    local auth_errors=$(grep -c "auth.*error\|authentication.*failed" "$LOG_FILE" 2>/dev/null || echo "0")
    local timeout_errors=$(grep -c "timeout" "$LOG_FILE" 2>/dev/null || echo "0")
    local rate_limit_errors=$(grep -c "rate.*limit" "$LOG_FILE" 2>/dev/null || echo "0")

    if [[ $auth_errors -gt 0 ]]; then
        echo -e "  ${RED}⚠${NC} Authentication Errors: $auth_errors"
        echo "    → Check PERPLEXITY_API_KEY environment variable"
    fi

    if [[ $timeout_errors -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠${NC} Timeout Errors: $timeout_errors"
        echo "    → Consider increasing timeout in .mcp.json"
    fi

    if [[ $rate_limit_errors -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠${NC} Rate Limit Errors: $rate_limit_errors"
        echo "    → Reduce request frequency or upgrade API plan"
    fi

    echo ""
}

show_cache_stats() {
    echo -e "${CYAN}Cache Performance${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

    if ! check_log_exists; then
        return 0
    fi

    local cache_hits=$(grep -c "cache.*hit" "$LOG_FILE" 2>/dev/null || echo "0")
    local cache_misses=$(grep -c "cache.*miss" "$LOG_FILE" 2>/dev/null || echo "0")
    local total_cached_requests=$((cache_hits + cache_misses))

    if [[ $total_cached_requests -eq 0 ]]; then
        echo -e "  ${YELLOW}No cache statistics available yet${NC}"
        echo ""
        return 0
    fi

    echo "  Cache Hits: ${GREEN}$cache_hits${NC}"
    echo "  Cache Misses: $cache_misses"

    # Calculate cache hit rate
    if [[ $total_cached_requests -gt 0 ]]; then
        local hit_rate=$(awk "BEGIN {printf \"%.1f\", ($cache_hits / $total_cached_requests) * 100}")
        echo "  Cache Hit Rate: ${hit_rate}%"
    fi

    echo ""
}

show_response_times() {
    echo -e "${CYAN}Response Time Analysis${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

    if ! check_log_exists; then
        return 0
    fi

    # Try to extract response times (format: response_time: XXXms)
    local times=$(grep -o "response_time[^0-9]*[0-9]*ms" "$LOG_FILE" 2>/dev/null | grep -o "[0-9]*" || echo "")

    if [[ -z "$times" ]]; then
        echo -e "  ${YELLOW}No response time data available${NC}"
        echo ""
        return 0
    fi

    # Calculate average (simple bash arithmetic)
    local count=0
    local sum=0
    while IFS= read -r time; do
        sum=$((sum + time))
        count=$((count + 1))
    done <<< "$times"

    if [[ $count -gt 0 ]]; then
        local avg=$((sum / count))
        echo "  Average Response Time: ${avg}ms"
        echo "  Total Requests Measured: $count"
    fi

    echo ""
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Display MCP usage statistics and analytics.

OPTIONS:
    -h, --help          Show this help message
    -s, --summary       Show summary only
    -e, --errors        Show errors only
    -c, --cache         Show cache statistics only
    -r, --recent        Show recent activity only

EXAMPLES:
    # Show all statistics
    $(basename "$0")

    # Show only summary
    $(basename "$0") --summary

    # Show only errors
    $(basename "$0") --errors

EOF
}

main() {
    local show_all=true
    local show_summary_only=false
    local show_errors_only=false
    local show_cache_only=false
    local show_recent_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--summary)
                show_all=false
                show_summary_only=true
                shift
                ;;
            -e|--errors)
                show_all=false
                show_errors_only=true
                shift
                ;;
            -c|--cache)
                show_all=false
                show_cache_only=true
                shift
                ;;
            -r|--recent)
                show_all=false
                show_recent_only=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    print_header

    # Ensure log directory exists
    mkdir -p "$LOG_DIR"

    if [[ "$show_all" == "true" ]]; then
        show_summary
        show_recent_activity
        show_error_details
        show_cache_stats
        show_response_times
    else
        [[ "$show_summary_only" == "true" ]] && show_summary
        [[ "$show_errors_only" == "true" ]] && show_error_details
        [[ "$show_cache_only" == "true" ]] && show_cache_stats
        [[ "$show_recent_only" == "true" ]] && show_recent_activity
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Log File: $LOG_FILE${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Run main
main "$@"
