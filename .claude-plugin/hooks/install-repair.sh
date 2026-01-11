#!/usr/bin/env bash
# install-repair.sh - Repair plugin installation issues
# Part of BMAD Ralph Plugin
# Version: 1.0.0

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPAIR_LOG="${PLUGIN_DIR}/../.ralph-cache/repair.log"

# Create log directory
mkdir -p "$(dirname "$REPAIR_LOG")"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] $message" >> "$REPAIR_LOG"
}

# Repair tracking
REPAIRS_ATTEMPTED=0
REPAIRS_SUCCESSFUL=0
REPAIRS_FAILED=0

# Print header
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  BMAD Ralph Plugin - Installation Repair${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

log "INFO" "Starting installation repair"

# ═══════════════════════════════════════════════════════════════════════════
# REPAIR FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

repair_directory_structure() {
    echo -e "${BLUE}[Repair]${NC} Checking directory structure..."

    local dirs_created=0

    REQUIRED_DIRS=(
        "commands"
        "skills"
        "agents"
        "hooks"
    )

    for dir in "${REQUIRED_DIRS[@]}"; do
        local dir_path="${PLUGIN_DIR}/${dir}"
        if [[ ! -d "$dir_path" ]]; then
            echo -e "  ${YELLOW}→${NC} Creating directory: ${dir}"
            mkdir -p "$dir_path"
            touch "${dir_path}/.gitkeep"
            ((dirs_created++))
            log "INFO" "Created directory: ${dir}"
        fi
    done

    if [[ $dirs_created -gt 0 ]]; then
        echo -e "  ${GREEN}✓${NC} Created ${dirs_created} missing directories"
        ((REPAIRS_SUCCESSFUL++))
    else
        echo -e "  ${GREEN}✓${NC} Directory structure OK"
    fi

    ((REPAIRS_ATTEMPTED++))
}

repair_hook_permissions() {
    echo -e "${BLUE}[Repair]${NC} Checking hook permissions..."

    local hooks_fixed=0
    local hooks_dir="${PLUGIN_DIR}/hooks"

    if [[ -d "$hooks_dir" ]]; then
        while IFS= read -r -d '' script; do
            if [[ ! -x "$script" ]]; then
                echo -e "  ${YELLOW}→${NC} Making executable: $(basename "$script")"
                chmod +x "$script"
                ((hooks_fixed++))
                log "INFO" "Made executable: $(basename "$script")"
            fi
        done < <(find "$hooks_dir" -name "*.sh" -type f -print0)

        if [[ $hooks_fixed -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} Fixed ${hooks_fixed} hook permissions"
            ((REPAIRS_SUCCESSFUL++))
        else
            echo -e "  ${GREEN}✓${NC} Hook permissions OK"
        fi
    else
        echo -e "  ${RED}✗${NC} Hooks directory not found"
        ((REPAIRS_FAILED++))
    fi

    ((REPAIRS_ATTEMPTED++))
}

repair_cache_directory() {
    echo -e "${BLUE}[Repair]${NC} Checking cache directory..."

    local cache_dir="${PLUGIN_DIR}/../.ralph-cache"

    if [[ ! -d "$cache_dir" ]]; then
        echo -e "  ${YELLOW}→${NC} Creating cache directory"
        mkdir -p "$cache_dir"
        log "INFO" "Created cache directory"
        echo -e "  ${GREEN}✓${NC} Created cache directory"
        ((REPAIRS_SUCCESSFUL++))
    else
        echo -e "  ${GREEN}✓${NC} Cache directory OK"
    fi

    ((REPAIRS_ATTEMPTED++))
}

install_dependencies() {
    echo -e "${BLUE}[Repair]${NC} Checking dependencies..."

    local missing_deps=()

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi

    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} All dependencies installed"
        ((REPAIRS_ATTEMPTED++))
        return 0
    fi

    echo -e "  ${YELLOW}⚠${NC} Missing dependencies: ${missing_deps[*]}"
    echo
    echo "Please install missing dependencies:"
    echo

    # macOS
    echo -e "${BLUE}macOS (Homebrew):${NC}"
    for dep in "${missing_deps[@]}"; do
        case "$dep" in
            yq)
                echo "  brew install yq"
                ;;
            *)
                echo "  brew install ${dep}"
                ;;
        esac
    done
    echo

    # Ubuntu/Debian
    echo -e "${BLUE}Ubuntu/Debian:${NC}"
    for dep in "${missing_deps[@]}"; do
        case "$dep" in
            yq)
                echo "  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
                echo "  sudo chmod +x /usr/local/bin/yq"
                ;;
            jq)
                echo "  sudo apt-get install jq"
                ;;
            git)
                echo "  sudo apt-get install git"
                ;;
        esac
    done
    echo

    # Fedora/RHEL
    echo -e "${BLUE}Fedora/RHEL:${NC}"
    for dep in "${missing_deps[@]}"; do
        case "$dep" in
            yq)
                echo "  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
                echo "  sudo chmod +x /usr/local/bin/yq"
                ;;
            *)
                echo "  sudo dnf install ${dep}"
                ;;
        esac
    done

    log "WARN" "Missing dependencies: ${missing_deps[*]}"
    ((REPAIRS_ATTEMPTED++))
    ((REPAIRS_FAILED++))
}

validate_json_files() {
    echo -e "${BLUE}[Repair]${NC} Validating JSON configuration files..."

    if ! command -v jq &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} jq not available - skipping JSON validation"
        log "WARN" "jq not available - skipping JSON validation"
        ((REPAIRS_ATTEMPTED++))
        return 0
    fi

    local json_files=(
        "plugin.json"
        "marketplace.json"
        ".mcp.json"
        "hooks/hooks.json"
    )

    local validation_errors=0

    for json_file in "${json_files[@]}"; do
        local file_path="${PLUGIN_DIR}/${json_file}"

        if [[ -f "$file_path" ]]; then
            if jq empty "$file_path" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} ${json_file}"
            else
                echo -e "  ${RED}✗${NC} ${json_file} - Invalid JSON syntax"
                ((validation_errors++))
                log "ERROR" "Invalid JSON: ${json_file}"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} ${json_file} - Not found"
            log "WARN" "Missing JSON file: ${json_file}"
        fi
    done

    if [[ $validation_errors -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} All JSON files valid"
        ((REPAIRS_SUCCESSFUL++))
    else
        echo -e "  ${RED}✗${NC} ${validation_errors} JSON validation error(s)"
        echo "  Manual intervention required to fix JSON syntax errors"
        ((REPAIRS_FAILED++))
    fi

    ((REPAIRS_ATTEMPTED++))
}

setup_mcp_environment() {
    echo -e "${BLUE}[Repair]${NC} Checking MCP environment..."

    if [[ -z "${PERPLEXITY_API_KEY:-}" ]]; then
        echo -e "  ${YELLOW}⚠${NC} PERPLEXITY_API_KEY not set"
        echo
        echo "To enable MCP features, set your Perplexity API key:"
        echo "  export PERPLEXITY_API_KEY='your-api-key-here'"
        echo
        echo "Or add to your shell profile (~/.bashrc, ~/.zshrc):"
        echo "  echo 'export PERPLEXITY_API_KEY=\"your-api-key-here\"' >> ~/.bashrc"
        echo
        log "WARN" "PERPLEXITY_API_KEY not set"
        ((REPAIRS_ATTEMPTED++))
        return 0
    fi

    echo -e "  ${GREEN}✓${NC} PERPLEXITY_API_KEY configured"
    ((REPAIRS_SUCCESSFUL++))
    ((REPAIRS_ATTEMPTED++))
}

# ═══════════════════════════════════════════════════════════════════════════
# RUN REPAIRS
# ═══════════════════════════════════════════════════════════════════════════

repair_directory_structure
repair_hook_permissions
repair_cache_directory
install_dependencies
validate_json_files
setup_mcp_environment

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "Repair Summary:"
echo -e "  Total repairs attempted: ${REPAIRS_ATTEMPTED}"
echo -e "  ${GREEN}Successful: ${REPAIRS_SUCCESSFUL}${NC}"

if [[ $REPAIRS_FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed: ${REPAIRS_FAILED}${NC}"
fi

echo

if [[ $REPAIRS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All repairs completed successfully${NC}"
    echo
    echo "Next steps:"
    echo "  1. Run validation: ${PLUGIN_DIR}/hooks/install-validate.sh"
    echo "  2. Review repair log: ${REPAIR_LOG}"
    log "INFO" "All repairs completed successfully"
else
    echo -e "${YELLOW}⚠ Some repairs require manual intervention${NC}"
    echo
    echo "Please:"
    echo "  1. Address the issues noted above"
    echo "  2. Run validation: ${PLUGIN_DIR}/hooks/install-validate.sh"
    echo "  3. Review repair log: ${REPAIR_LOG}"
    log "WARN" "Some repairs require manual intervention"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Exit with appropriate code
if [[ $REPAIRS_FAILED -eq 0 ]]; then
    exit 0
else
    exit 1
fi
