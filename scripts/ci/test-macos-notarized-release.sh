#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/scripts/ci/run-macos-notarized-release.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

required_log="$tmp_dir/required.log"
dry_run_log="$tmp_dir/dry-run.log"

if RELEASE_VERSION=1.0.0 "$script" >"$required_log" 2>&1; then
  echo "notarized release script accepted missing credentials." >&2
  exit 1
fi
grep -q "APPLE_DEVELOPER_CERT_P12" "$required_log"

env \
  RELEASE_VERSION=1.0.0 \
  FLAPLINE_NOTARIZE_DRY_RUN=1 \
  APPLE_DEVELOPER_CERT_P12=dGVzdA== \
  APPLE_CERT_PASSWORD=test \
  APPLE_NOTARY_KEY_ID=KEYID12345 \
  APPLE_NOTARY_KEY_ISSUER=00000000-0000-0000-0000-000000000000 \
  APPLE_NOTARY_PRIVATE_KEY=dGVzdA== \
  "$script" >"$dry_run_log" 2>&1
grep -q "dry run requested" "$dry_run_log"
echo "Flapline notarization script tests passed."
