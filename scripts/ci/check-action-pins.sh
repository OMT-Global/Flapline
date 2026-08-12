#!/usr/bin/env bash
set -euo pipefail

python3 - "${1:-.github/workflows}" <<'PY'
import re
import sys
from pathlib import Path

workflow_root = Path(sys.argv[1])
uses_pattern = re.compile(r"^\s*(?:-\s+)?uses:\s*([^\s#]+)@([^\s#]+)(?:\s+#\s*(.+))?\s*$")
sha_pattern = re.compile(r"^[0-9a-f]{40}$")
failures = []
checked = 0

for workflow in sorted([*workflow_root.rglob("*.yml"), *workflow_root.rglob("*.yaml")]):
    for line_number, line in enumerate(workflow.read_text().splitlines(), start=1):
        match = uses_pattern.match(line)
        if not match:
            continue
        action, ref, metadata = match.groups()
        if action.startswith("./") or action.startswith("OMT-Global/bootstrap/"):
            continue
        checked += 1
        location = f"{workflow}:{line_number}"
        if not sha_pattern.fullmatch(ref):
            failures.append(f"SA-ACTION-PIN-001 {location}: {action}@{ref} is not an immutable 40-character commit SHA.")
        elif not metadata:
            failures.append(f"SA-ACTION-PIN-002 {location}: {action} is pinned but lacks readable tag or release metadata after '#'.")

if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)

print(f"PASS SA-ACTION-PIN-000: validated {checked} third-party action pin(s) under {workflow_root}.")
PY
