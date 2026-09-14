#!/usr/bin/env bash
# All remote workflow actions must name an immutable Git commit.
set -euo pipefail
failed=0
while IFS= read -r occurrence; do
  ref="${occurrence#*uses: }"
  ref="${ref%% *}"
  if [[ ! "$ref" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}$ ]]; then
    echo "Unpinned remote action: $occurrence" >&2
    failed=1
  fi
done < <(grep -nE 'uses: [A-Za-z0-9_.-]+/' .github/workflows/*.yml || true)
exit "$failed"
