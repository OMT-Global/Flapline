#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/.github/workflows"
cd "$scratch"
printf '%s\n' 'steps:' '  - uses: actions/checkout@0123456789012345678901234567890123456789 # v4' > .github/workflows/check.yml
bash "$root/scripts/ci/check-action-pins.sh"
printf '%s\n' '  - uses: actions/checkout@v4' >> .github/workflows/check.yml
if bash "$root/scripts/ci/check-action-pins.sh"; then
  echo 'Mutable action negative control was not rejected' >&2
  exit 1
fi
echo 'PASS immutable pin positive and mutable tag negative control'
