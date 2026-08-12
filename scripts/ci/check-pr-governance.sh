#!/usr/bin/env bash
set -euo pipefail

required=(PR_TITLE PR_BODY PR_AUTHOR)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required PR governance input: $name" >&2
    exit 2
  fi
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fetch() {
  local url="$1"
  local destination="$2"
  curl --fail --silent --show-error --location --retry 2 \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $GITHUB_TOKEN" \
    "$url" >"$destination"
}

load_response() {
  local fixture="$1"
  local url="$2"
  local suffix="$3"
  local destination="$4"
  if [[ -n "$fixture" ]]; then
    cp "$fixture" "$destination"
  elif [[ -n "$url" && -n "${GITHUB_TOKEN:-}" ]]; then
    fetch "$url?$suffix" "$destination"
  else
    echo "Provide a fixture file or API URL plus GITHUB_TOKEN for $destination" >&2
    exit 2
  fi
}

load_response "${PR_FILES_FILE:-}" "${PR_FILES_URL:-}" "per_page=100" "$workdir/files.json"
load_response "${PR_COMMITS_FILE:-}" "${PR_COMMITS_URL:-}" "per_page=250" "$workdir/commits.json"
load_response "${PR_REVIEWS_FILE:-}" "${PR_REVIEWS_URL:-}" "per_page=100" "$workdir/reviews.json"

python3 - "$PR_TITLE" "$PR_BODY" "$PR_AUTHOR" "${PR_CREATED_AT:-}" "${PR_GOVERNANCE_ENFORCE_AFTER:-}" "$workdir/files.json" "$workdir/commits.json" "$workdir/reviews.json" <<'PY'
from datetime import datetime
import json
import re
import sys
from pathlib import Path

title, body, author, created_at, enforce_after, files_path, commits_path, reviews_path = sys.argv[1:]
files = json.loads(Path(files_path).read_text())
commits = json.loads(Path(commits_path).read_text())
reviews = json.loads(Path(reviews_path).read_text())
failures = []

if enforce_after:
    try:
        created_at_value = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        enforce_after_value = datetime.fromisoformat(enforce_after.replace("Z", "+00:00"))
        if created_at_value.tzinfo is None or enforce_after_value.tzinfo is None:
            raise ValueError
    except ValueError:
        failures.append("PRS-ENFORCEMENT-INPUT-001: PR_CREATED_AT and PR_GOVERNANCE_ENFORCE_AFTER must be ISO-8601 timestamps.")
    else:
        if created_at_value < enforce_after_value:
            print(f"PASS PRS-PR-GOVERNANCE-LEGACY-001: PR opened at {created_at} before enforcement began at {enforce_after}.")
            sys.exit(0)

if not re.match(r"^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([^)]+\))?!?: .+", title):
    failures.append("PRS-PR-TITLE-001: use a Conventional Commit-style PR title, for example 'feat: add policy gate'.")

excluded = []
counted_lines = 0
for changed in files:
    name = changed.get("filename", "unknown")
    if name.startswith(("docs/", "test/", "tests/")) or name.endswith((".md", ".lock")) or name in {"package-lock.json", "pnpm-lock.yaml", "yarn.lock"}:
        excluded.append(name)
    else:
        counted_lines += int(changed.get("additions", 0)) + int(changed.get("deletions", 0))
print(f"INFO PRS-PR-SIZE-001: {counted_lines} counted changed lines; excluded {len(excluded)} documentation, test, and lockfile paths.")
if excluded:
    print("INFO PRS-PR-SIZE-001 excluded: " + ", ".join(sorted(excluded)))
if counted_lines > 800:
    failures.append(f"PRS-PR-SIZE-001: {counted_lines} counted changed lines exceeds the 800-line review threshold; split the change before requesting review.")

missing_dco = []
for commit in commits:
    login = (commit.get("author") or {}).get("login", "")
    account_type = (commit.get("author") or {}).get("type", "")
    if account_type == "Bot" or login.endswith("[bot]"):
        continue
    message = (commit.get("commit") or {}).get("message", "")
    if not re.search(r"(?im)^signed-off-by:\s+.+ <[^>]+>$", message):
        missing_dco.append(commit.get("sha", "unknown")[:12])
if missing_dco:
    failures.append("PRS-DCO-001: contributed commits without a Signed-off-by trailer: " + ", ".join(missing_dco))

declaration = re.search(r"(?im)^material change:\s*(yes|no)\s*$", body)
if not declaration:
    failures.append("PRS-MATERIAL-001: declare 'Material change: yes' or 'Material change: no' in the PR body.")
elif declaration.group(1).lower() == "yes":
    adr = re.search(r"(?im)^adr:\s*(docs/decisions/[^\s]+\.md)\s*$", body)
    if not adr:
        failures.append("PRS-ADR-001: material changes require an ADR line pointing at an accepted docs/decisions/*.md file.")
    else:
        adr_path = Path(adr.group(1))
        if not adr_path.is_file() or not re.search(r"(?im)^status:\s*accepted\s*$", adr_path.read_text()):
            failures.append(f"PRS-ADR-001: {adr_path} must exist in this PR and declare 'Status: Accepted'.")

    independent_approvers = {
        (review.get("user") or {}).get("login", "")
        for review in reviews
        if review.get("state", "").upper() == "APPROVED"
        and (review.get("user") or {}).get("login", "") != author
        and (review.get("user") or {}).get("type", "") != "Bot"
    }
    if not independent_approvers:
        failures.append("PRS-INDEPENDENT-REVIEW-001: material changes require an approving reviewer other than the PR author.")

if failures:
    print("\n".join("FAIL " + failure for failure in failures), file=sys.stderr)
    sys.exit(1)
print("PASS PRS-PR-GOVERNANCE-001: title, DCO, change accounting, and material evidence are valid.")
PY
