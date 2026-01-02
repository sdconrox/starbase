#!/bin/bash
# Comprehensive credential scanner using multiple tools
# Runs: gitleaks, truffleHog, git-secrets, and detect-secrets

# Don't exit on error - we want to run all tools even if some fail
set +e

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
    echo "   Scanning filesystem (uncommitted files)..."
    OUTPUT_FILE="$RESULTS_DIR/gitleaks-results.json"
    # Use --no-git to scan filesystem instead of git commits
    gitleaks detect --source "$SCAN_DIR" --no-git --report-path "$OUTPUT_FILE" --verbose 2>&1 | tee "$RESULTS_DIR/gitleaks-output.txt"
    GITLEAKS_EXIT=$?
    TOOLS_RAN=$((TOOLS_RAN + 1))

    # Check if results file exists and has findings
    if [ -s "$OUTPUT_FILE" ]; then
        # Check if JSON has any findings (gitleaks outputs array of findings)
        FINDING_COUNT=$(jq 'if type == "array" then length else 0 end' "$OUTPUT_FILE" 2>/dev/null || echo 0)
        if [ "$FINDING_COUNT" -gt 0 ]; then
            echo -e "${RED}⚠️  gitleaks found $FINDING_COUNT potential secret(s)!${NC}"
            echo "   Results saved to: $OUTPUT_FILE"
        else
            echo -e "${GREEN}✓ gitleaks: No secrets detected${NC}"
        fi
    elif [ $GITLEAKS_EXIT -ne 0 ]; then
        # gitleaks exits with non-zero when secrets found
        if grep -q "leaks found" "$RESULTS_DIR/gitleaks-output.txt" 2>/dev/null; then
            echo -e "${RED}⚠️  gitleaks found potential secrets!${NC}"
            echo "   Check output: $RESULTS_DIR/gitleaks-output.txt"
        else
            echo -e "${GREEN}✓ gitleaks: No secrets detected${NC}"
        fi
    else
        echo -e "${GREEN}✓ gitleaks: No secrets detected${NC}"
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
    echo -e "${YELLOW}   Note: truffleHog v2.x only scans git commit history, not uncommitted files${NC}"
    OUTPUT_FILE="$RESULTS_DIR/trufflehog-results.json"
    # Check if this is a git repo (truffleHog v2.x requires git repo)
    if [ -d .git ]; then
        # Use git repo path for older truffleHog versions (scans git history only)
        trufflehog --json "$SCAN_DIR" > "$OUTPUT_FILE" 2>&1 | tee "$RESULTS_DIR/trufflehog-output.txt"
        TRUFFLEHOG_EXIT=$?
        TOOLS_RAN=$((TOOLS_RAN + 1))

        # Check if results contain any findings (non-empty JSON array)
        if [ -s "$OUTPUT_FILE" ]; then
            # Check if it's valid JSON and has content
            if jq -e '. | length > 0' "$OUTPUT_FILE" >/dev/null 2>&1; then
                echo -e "${RED}⚠️  truffleHog found potential secrets in git history!${NC}"
                echo "   Results saved to: $OUTPUT_FILE"
            else
                echo -e "${GREEN}✓ truffleHog: No secrets detected in git history${NC}"
            fi
        else
            echo -e "${GREEN}✓ truffleHog: No secrets detected in git history${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  truffleHog requires a git repository. Skipping...${NC}"
        echo "   (This directory is not a git repository)"
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
    echo "   Scanning filesystem (including untracked files)..."
    OUTPUT_FILE="$RESULTS_DIR/git-secrets-results.txt"
    # Initialize git-secrets if not already done
    if [ -d .git ]; then
        git secrets --install 2>/dev/null || true
        # Register AWS patterns if not already registered
        git secrets --register-aws 2>/dev/null || true
    fi
    # Scan the current directory recursively, including untracked files and files not in git index
    # --untracked: scan untracked files
    # --no-index: scan files not managed by git
    # -r: recursive
    git secrets --scan -r . 2>&1 | tee "$OUTPUT_FILE"
    SCAN_EXIT=$?
    TOOLS_RAN=$((TOOLS_RAN + 1))

    # Check output for matches (git-secrets exits with non-zero if secrets found)
    if grep -q "matches prohibited pattern" "$OUTPUT_FILE" 2>/dev/null || [ $SCAN_EXIT -ne 0 ]; then
        echo -e "${RED}⚠️  git-secrets found potential secrets!${NC}"
        echo "   Results saved to: $OUTPUT_FILE"
    else
        echo -e "${GREEN}✓ git-secrets: No secrets detected${NC}"
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
    echo "   Scanning all files (including uncommitted)..."
    BASELINE_FILE="$RESULTS_DIR/.secrets.baseline"
    OUTPUT_FILE="$RESULTS_DIR/detect-secrets-results.txt"

    # Scan and create baseline - use --all-files to scan uncommitted files
    # Redirect stderr to output file, stdout to baseline
    detect-secrets scan --all-files . > "$BASELINE_FILE" 2>>"$OUTPUT_FILE"
    SCAN_EXIT=$?

    if [ -s "$BASELINE_FILE" ]; then
        TOOLS_RAN=$((TOOLS_RAN + 1))
        echo "Baseline created. Checking for secrets..." | tee -a "$OUTPUT_FILE"

        # Check if baseline has any results
        if jq -e '.results | length > 0' "$BASELINE_FILE" >/dev/null 2>&1; then
            SECRET_COUNT=$(jq '.results | length' "$BASELINE_FILE" 2>/dev/null || echo 0)
            echo -e "${RED}⚠️  detect-secrets found $SECRET_COUNT potential secret(s)!${NC}"
            echo "   Baseline saved to: $BASELINE_FILE"
            echo ""
            echo "   To audit these findings, run:"
            echo "   detect-secrets audit $BASELINE_FILE"

            # Try to run audit if baseline has results
            echo "" | tee -a "$OUTPUT_FILE"
            echo "Running audit..." | tee -a "$OUTPUT_FILE"
            detect-secrets audit "$BASELINE_FILE" 2>&1 | tee -a "$OUTPUT_FILE" || true
        else
            echo -e "${GREEN}✓ detect-secrets: No secrets detected${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  detect-secrets scan had issues${NC}"
        if [ -s "$OUTPUT_FILE" ]; then
            echo "   Check output: $OUTPUT_FILE"
        fi
        TOOLS_RAN=$((TOOLS_RAN + 1))
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

