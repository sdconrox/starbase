#!/usr/bin/env bash
# Check sync-wave ordering for platform and argocd applications

set -euo pipefail

BASE_DIR="gitops/clusters/starbase"
SEARCH_DIRS=(
  "${BASE_DIR}/applications/platform"
  "${BASE_DIR}/argocd"
)

echo "Sync-Wave | Application"
echo "----------|------------"

# Temporary file for sorting
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# Extract sync-wave values
for dir in "${SEARCH_DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    continue
  fi

  grep -r "argocd.argoproj.io/sync-wave" "$dir" 2>/dev/null | while IFS=: read -r file line; do
    # Extract sync-wave value
    wave=$(echo "$line" | sed -n 's/.*sync-wave: "\([^"]*\)".*/\1/p')

    # Extract application name from filename
    app=$(basename "$file" | sed 's/-application\.yaml$//; s/\.yaml$//')

    if [[ -n "$wave" && -n "$app" ]]; then
      # Convert to integer for proper numeric sorting (handles negatives)
      printf "%d|%s|%s\n" "$wave" "$wave" "$app" >> "$TMPFILE"
    fi
  done
done

# Sort numerically and display
sort -t'|' -k1 -n "$TMPFILE" | awk -F'|' '{printf "%9s | %s\n", $2, $3}'
