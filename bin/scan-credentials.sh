#!/bin/bash
# Comprehensive credential scanner using multiple tools
# Runs: gitleaks, truffleHog, git-secrets, and detect-secrets

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the project root directory (parent of bin/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCAN_DIR="$PROJECT_ROOT"
RESULTS_DIR="$PROJECT_ROOT/credential-scan-results"
mkdir -p "$RESULTS_DIR"

# Change to project root for scanning
cd "$PROJECT_ROOT"

echo -e "${BLUE}🔍 Comprehensive Credential Scanning${NC}"
echo "=========================================="
echo "Scanning directory: $SCAN_DIR"
echo ""

# Track which tools ran
TOOLS_RAN=0
TOOLS_AVAILABLE=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print section header
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 1. GITLEAKS
print_header "1️⃣  Running gitleaks..."
if command_exists gitleaks; then
    TOOLS_AVAILABLE=$((TOOLS_AVAILABLE + 1))
    echo -e "${GREEN}✓ gitleaks found${NC}"
    OUTPUT_FILE="$RESULTS_DIR/gitleaks-results.json"
    if gitleaks detect --source "$SCAN_DIR" --report-path "$OUTPUT_FILE" --verbose 2>&1 | tee "$RESULTS_DIR/gitleaks-output.txt"; then
        TOOLS_RAN=$((TOOLS_RAN + 1))
        if [ -s "$OUTPUT_FILE" ] && [ "$(cat "$OUTPUT_FILE" | jq 'length' 2>/dev/null || echo 0)" != "0" ]; then
            echo -e "${RED}⚠️  gitleaks found potential secrets!${NC}"
            echo "   Results saved to: $OUTPUT_FILE"
        else
            echo -e "${GREEN}✓ gitleaks: No secrets detected${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  gitleaks scan completed with warnings${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  gitleaks not installed${NC}"
    echo "   Install with: ./bin/install-credential-scanners.sh"
    echo "   Or: brew install gitleaks"
fi

# 2. TRUFFLEHOG
print_header "2️⃣  Running truffleHog..."
if command_exists trufflehog; then
    TOOLS_AVAILABLE=$((TOOLS_AVAILABLE + 1))
    echo -e "${GREEN}✓ truffleHog found${NC}"
    OUTPUT_FILE="$RESULTS_DIR/trufflehog-results.json"
    if trufflehog filesystem --directory "$SCAN_DIR" --json --output "$OUTPUT_FILE" 2>&1 | tee "$RESULTS_DIR/trufflehog-output.txt"; then
        TOOLS_RAN=$((TOOLS_RAN + 1))
        if [ -s "$OUTPUT_FILE" ] && [ "$(cat "$OUTPUT_FILE" | jq 'length' 2>/dev/null || echo 0)" != "0" ]; then
            echo -e "${RED}⚠️  truffleHog found potential secrets!${NC}"
            echo "   Results saved to: $OUTPUT_FILE"
        else
            echo -e "${GREEN}✓ truffleHog: No secrets detected${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  truffleHog scan completed with warnings${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  truffleHog not installed${NC}"
    echo "   Install with: ./bin/install-credential-scanners.sh"
    echo "   Or: pip3 install truffleHog"
fi

# 3. GIT-SECRETS
print_header "3️⃣  Running git-secrets..."
if command_exists git-secrets; then
    TOOLS_AVAILABLE=$((TOOLS_AVAILABLE + 1))
    echo -e "${GREEN}✓ git-secrets found${NC}"
    OUTPUT_FILE="$RESULTS_DIR/git-secrets-results.txt"
    # Initialize git-secrets if not already done
    if [ -d .git ]; then
        git secrets --install 2>/dev/null || true
    fi
    if git secrets --scan -r "$SCAN_DIR" 2>&1 | tee "$OUTPUT_FILE"; then
        TOOLS_RAN=$((TOOLS_RAN + 1))
        if [ -s "$OUTPUT_FILE" ] && grep -q "matches prohibited pattern" "$OUTPUT_FILE" 2>/dev/null; then
            echo -e "${RED}⚠️  git-secrets found potential secrets!${NC}"
            echo "   Results saved to: $OUTPUT_FILE"
        else
            echo -e "${GREEN}✓ git-secrets: No secrets detected${NC}"
        fi
    else
        # git-secrets exits with non-zero if secrets found, so check output
        if [ -s "$OUTPUT_FILE" ] && grep -q "matches prohibited pattern" "$OUTPUT_FILE" 2>/dev/null; then
            echo -e "${RED}⚠️  git-secrets found potential secrets!${NC}"
            echo "   Results saved to: $OUTPUT_FILE"
        else
            echo -e "${GREEN}✓ git-secrets: No secrets detected${NC}"
        fi
        TOOLS_RAN=$((TOOLS_RAN + 1))
    fi
else
    echo -e "${YELLOW}⚠️  git-secrets not installed${NC}"
    echo "   Install with: ./bin/install-credential-scanners.sh"
    echo "   Or: brew install git-secrets"
fi

# 4. DETECT-SECRETS
print_header "4️⃣  Running detect-secrets..."
if command_exists detect-secrets; then
    TOOLS_AVAILABLE=$((TOOLS_AVAILABLE + 1))
    echo -e "${GREEN}✓ detect-secrets found${NC}"
    BASELINE_FILE="$RESULTS_DIR/.secrets.baseline"
    OUTPUT_FILE="$RESULTS_DIR/detect-secrets-results.txt"

    # Scan and create baseline
    if detect-secrets scan "$SCAN_DIR" > "$BASELINE_FILE" 2>&1 | tee "$OUTPUT_FILE"; then
        TOOLS_RAN=$((TOOLS_RAN + 1))
        # Audit the baseline
        if detect-secrets audit "$BASELINE_FILE" 2>&1 | tee -a "$OUTPUT_FILE"; then
            # Check if any secrets were found
            if [ -s "$BASELINE_FILE" ] && grep -q '"results":\s*{' "$BASELINE_FILE" 2>/dev/null; then
                SECRET_COUNT=$(cat "$BASELINE_FILE" | jq '.results | length' 2>/dev/null || echo 0)
                if [ "$SECRET_COUNT" != "0" ] && [ "$SECRET_COUNT" != "null" ]; then
                    echo -e "${RED}⚠️  detect-secrets found $SECRET_COUNT potential secret(s)!${NC}"
                    echo "   Baseline saved to: $BASELINE_FILE"
                else
                    echo -e "${GREEN}✓ detect-secrets: No secrets detected${NC}"
                fi
            else
                echo -e "${GREEN}✓ detect-secrets: No secrets detected${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  detect-secrets scan completed with warnings${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  detect-secrets not installed${NC}"
    echo "   Install with: ./bin/install-credential-scanners.sh"
    echo "   Or: pip3 install detect-secrets"
fi

# Summary
print_header "📊 Scan Summary"
echo -e "Tools available: ${GREEN}$TOOLS_AVAILABLE/4${NC}"
echo -e "Tools executed: ${GREEN}$TOOLS_RAN/$TOOLS_AVAILABLE${NC}"
echo ""
echo "Results directory: $RESULTS_DIR"
echo ""
echo "To view results:"
echo "  - gitleaks: cat $RESULTS_DIR/gitleaks-results.json | jq"
echo "  - truffleHog: cat $RESULTS_DIR/trufflehog-results.json | jq"
echo "  - git-secrets: cat $RESULTS_DIR/git-secrets-results.txt"
echo "  - detect-secrets: cat $RESULTS_DIR/detect-secrets-results.txt"
echo ""

if [ $TOOLS_AVAILABLE -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No scanning tools are installed.${NC}"
    echo ""
    echo "Install all tools with:"
    echo "  ./bin/install-credential-scanners.sh"
fi

echo -e "${BLUE}✅ Scan complete!${NC}"

