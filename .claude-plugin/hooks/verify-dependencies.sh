#!/usr/bin/env bash
# BMAD Ralph Plugin - Dependency Verification
# Verifies required system dependencies are installed

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=()
MISSING_DEPS=()

echo "Verifying BMAD Ralph plugin dependencies..."
echo ""

# Function to compare versions
version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Check jq
echo -n "Checking jq... "
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version 2>&1 | sed 's/jq-//')
    if version_ge "$JQ_VERSION" "1.6"; then
        echo -e "${GREEN}✓${NC} jq $JQ_VERSION (>= 1.6 required)"
    else
        echo -e "${RED}✗${NC} jq $JQ_VERSION found, but >= 1.6 required"
        ERRORS+=("jq version $JQ_VERSION is too old. Version >= 1.6 is required.")
        MISSING_DEPS+=("jq")
    fi
else
    echo -e "${RED}✗${NC} not found"
    ERRORS+=("jq is not installed.")
    MISSING_DEPS+=("jq")
fi

# Check yq
echo -n "Checking yq... "
if command -v yq &> /dev/null; then
    YQ_VERSION=$(yq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    YQ_MAJOR=$(echo "$YQ_VERSION" | cut -d. -f1)
    if [ "$YQ_MAJOR" -ge 4 ]; then
        echo -e "${GREEN}✓${NC} yq $YQ_VERSION (>= 4.0 required)"
    else
        echo -e "${RED}✗${NC} yq $YQ_VERSION found, but >= 4.0 required"
        ERRORS+=("yq version $YQ_VERSION is too old. Version >= 4.0 is required.")
        MISSING_DEPS+=("yq")
    fi
else
    echo -e "${RED}✗${NC} not found"
    ERRORS+=("yq is not installed.")
    MISSING_DEPS+=("yq")
fi

# Check git
echo -n "Checking git... "
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
    if version_ge "$GIT_VERSION" "2.0"; then
        echo -e "${GREEN}✓${NC} git $GIT_VERSION (>= 2.0 required)"
    else
        echo -e "${RED}✗${NC} git $GIT_VERSION found, but >= 2.0 required"
        ERRORS+=("git version $GIT_VERSION is too old. Version >= 2.0 is required.")
        MISSING_DEPS+=("git")
    fi
else
    echo -e "${RED}✗${NC} not found"
    ERRORS+=("git is not installed.")
    MISSING_DEPS+=("git")
fi

echo ""

# If there are errors, show installation instructions
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Dependency verification failed${NC}"
    echo ""
    echo "The following issues were found:"
    for error in "${ERRORS[@]}"; do
        echo "  • $error"
    done
    echo ""
    echo -e "${YELLOW}Installation Instructions:${NC}"
    echo ""

    # Show installation instructions for missing dependencies
    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            jq)
                echo "📦 jq (JSON processor)"
                echo "  macOS:    brew install jq"
                echo "  Ubuntu:   sudo apt-get install jq"
                echo "  Fedora:   sudo dnf install jq"
                echo "  Windows:  choco install jq"
                echo "  Or visit: https://stedolan.github.io/jq/download/"
                echo ""
                ;;
            yq)
                echo "📦 yq (YAML processor, v4+)"
                echo "  macOS:    brew install yq"
                echo "  Ubuntu:   sudo snap install yq"
                echo "  Fedora:   sudo dnf install yq"
                echo "  Windows:  choco install yq"
                echo "  Or visit: https://github.com/mikefarah/yq#install"
                echo ""
                ;;
            git)
                echo "📦 git (version control)"
                echo "  macOS:    brew install git"
                echo "  Ubuntu:   sudo apt-get install git"
                echo "  Fedora:   sudo dnf install git"
                echo "  Windows:  choco install git"
                echo "  Or visit: https://git-scm.com/downloads"
                echo ""
                ;;
        esac
    done

    echo "After installing the dependencies, restart Claude Code to retry verification."
    exit 1
fi

echo -e "${GREEN}✅ All dependencies verified successfully!${NC}"
exit 0
