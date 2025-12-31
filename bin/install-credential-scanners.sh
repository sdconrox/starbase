#!/bin/bash
# Install script for credential scanning tools
# Installs: gitleaks, truffleHog, git-secrets, and detect-secrets

# Don't exit on error - we want to try installing all tools even if some fail
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Installing Credential Scanning Tools${NC}"
echo "=========================================="
echo ""

# Track installation status
INSTALLED=0
FAILED=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        INSTALLED=$((INSTALLED + 1))
    else
        echo -e "${RED}✗ $1 failed${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# Check for required package managers
if ! command_exists brew; then
    echo -e "${YELLOW}⚠️  Homebrew not found. Some tools require Homebrew.${NC}"
    echo "   Install Homebrew from: https://brew.sh"
    echo ""
fi

if ! command_exists pip3; then
    echo -e "${YELLOW}⚠️  pip3 not found. Some tools require pip3.${NC}"
    echo "   Python 3 is required for truffleHog and detect-secrets"
    echo ""
fi

# 1. Install gitleaks
echo -e "${BLUE}1️⃣  Installing gitleaks...${NC}"
if command_exists gitleaks; then
    echo -e "${GREEN}✓ gitleaks already installed${NC}"
    gitleaks version
    INSTALLED=$((INSTALLED + 1))
else
    if command_exists brew; then
        brew install gitleaks 2>&1
        print_status "gitleaks installed via Homebrew"
    else
        echo -e "${YELLOW}⚠️  Homebrew not available. Install gitleaks manually:${NC}"
        echo "   Download from: https://github.com/gitleaks/gitleaks/releases"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# 2. Install truffleHog
echo -e "${BLUE}2️⃣  Installing truffleHog...${NC}"
if command_exists trufflehog; then
    echo -e "${GREEN}✓ truffleHog already installed${NC}"
    trufflehog --version 2>/dev/null || echo "truffleHog installed"
    INSTALLED=$((INSTALLED + 1))
else
    if command_exists pip3; then
        pip3 install truffleHog 2>&1
        print_status "truffleHog installed via pip3"
    else
        echo -e "${YELLOW}⚠️  pip3 not available. Install truffleHog manually:${NC}"
        echo "   pip3 install truffleHog"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# 3. Install git-secrets
echo -e "${BLUE}3️⃣  Installing git-secrets...${NC}"
if command_exists git-secrets; then
    echo -e "${GREEN}✓ git-secrets already installed${NC}"
    git-secrets --version 2>/dev/null || echo "git-secrets installed"
    INSTALLED=$((INSTALLED + 1))
else
    if command_exists brew; then
        brew install git-secrets 2>&1
        print_status "git-secrets installed via Homebrew"
    else
        echo -e "${YELLOW}⚠️  Homebrew not available. Install git-secrets manually:${NC}"
        echo "   See: https://github.com/awslabs/git-secrets"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# 4. Install detect-secrets
echo -e "${BLUE}4️⃣  Installing detect-secrets...${NC}"
if command_exists detect-secrets; then
    echo -e "${GREEN}✓ detect-secrets already installed${NC}"
    detect-secrets --version 2>/dev/null || echo "detect-secrets installed"
    INSTALLED=$((INSTALLED + 1))
else
    if command_exists pip3; then
        pip3 install detect-secrets 2>&1
        print_status "detect-secrets installed via pip3"
    else
        echo -e "${YELLOW}⚠️  pip3 not available. Install detect-secrets manually:${NC}"
        echo "   pip3 install detect-secrets"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Installation Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Successfully installed/available: ${GREEN}$INSTALLED/4${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "Failed or skipped: ${RED}$FAILED${NC}"
fi
echo ""

if [ $INSTALLED -eq 4 ]; then
    echo -e "${GREEN}✅ All tools are ready!${NC}"
    echo ""
    echo "You can now run the credential scanner:"
    echo "  ./bin/scan-credentials.sh"
elif [ $INSTALLED -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some tools are available. You can run the scanner with what's installed.${NC}"
    echo ""
    echo "Run the credential scanner:"
    echo "  ./bin/scan-credentials.sh"
else
    echo -e "${RED}❌ No tools were installed. Please install dependencies manually.${NC}"
fi

echo ""

