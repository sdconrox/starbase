#!/usr/bin/env bash
# Download and format MetalLB CRDs for easy replacement in metallb.yaml

set -uo pipefail

# Default version (can be overridden with first argument)
VERSION="${1:-v0.15.3}"

# Base URL for MetalLB CRDs
BASE_URL="https://raw.githubusercontent.com/metallb/metallb/${VERSION}/config/crd/bases"

# List of CRD files in order (matching typical MetalLB structure)
CRDS=(
    "metallb.io_bfdprofiles.yaml"
    "metallb.io_bgpadvertisements.yaml"
    "metallb.io_bgppeers.yaml"
    "metallb.io_communities.yaml"
    "metallb.io_ipaddresspools.yaml"
    "metallb.io_l2advertisements.yaml"
    "metallb.io_servicel2statuses.yaml"
    "metallb.io_servicebgpstatuses.yaml"
)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

printf "Downloading MetalLB CRDs for version ${GREEN}%s${NC}...\n" "$VERSION"
echo ""

# Temporary directory for downloads
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Download all CRDs
DOWNLOADED=0
FAILED=0

for crd in "${CRDS[@]}"; do
    url="${BASE_URL}/${crd}"
    output="${TMPDIR}/${crd}"

    printf "Downloading %s... " "$crd"
    if curl -sSL -o "$output" "$url" 2>/dev/null && [ -s "$output" ]; then
        printf "${GREEN}✓${NC}\n"
        DOWNLOADED=$((DOWNLOADED + 1))
    else
        printf "${YELLOW}✗ (not found)${NC}\n"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
printf "Downloaded: ${GREEN}%d${NC} CRDs\n" "$DOWNLOADED"
if [ $FAILED -gt 0 ]; then
    printf "Failed: ${YELLOW}%d${NC} CRDs\n" "$FAILED"
fi

if [ $DOWNLOADED -eq 0 ]; then
    echo "Error: No CRDs downloaded. Check version and network connection."
    exit 1
fi

echo ""
echo "=========================================="
echo "CRDs ready to paste:"
echo "=========================================="
echo ""

# Output CRDs with separators (no header comments, just the CRDs)
for crd in "${CRDS[@]}"; do
    crd_file="${TMPDIR}/${crd}"
    if [ -f "$crd_file" ] && [ -s "$crd_file" ]; then
        cat "$crd_file"
        echo "---"
    fi
done

echo ""
echo "=========================================="
echo ""
echo "To use:"
echo "  1. Copy all CRDs above (including the --- separators)"
echo "  2. In metallb.yaml, replace the CRD section (from first CRD to last CRD)"
echo "  3. Keep the namespace at the top and ServiceAccount section at the bottom"
