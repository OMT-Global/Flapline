# Report-First Issue Hygiene

`.github/workflows/issue-hygiene.yml` inventories open issues every Monday and on manual dispatch. It uses only `contents: read` and `issues: read`, writes a complete versioned JSON artifact, and appends a Markdown report capped at 900 KiB to the workflow summary.

## Aging Rules

- Fewer than 30 inactive days: current; no report entry.
- At least 30 inactive days: review proposal.
- At least 90 inactive days without a credible next action: close-or-rescope proposal that requires a maintainer decision.
- Automation never comments, labels, closes, reschedules, or otherwise mutates an issue.

GitHub's `updated_at` timestamp is the inactivity source. Pull requests returned by the issues API are excluded.

## Preserve A Stale Issue

Add one structured marker to the issue body. `outcome` or an evidence-shaped `dependency` is required, `checkpoint` must be a future ISO date, and `evidence` must be a canonical public GitHub issue, pull-request, or Actions-run URL without query or fragment data, or a positive numeric `issue:`, `pr:`, or `run:` reference.

```html
<!-- prs-next-action {"outcome":"Ship resolver","dependency":"issue:54","checkpoint":"2026-08-01","evidence":"issue:10"} -->
```

The report publishes only the issue number, single-line title, URL, timestamps, checkpoint, and evidence reference. It never emits the issue body or the next-action outcome.

## Local Fixture

```sh
node scripts/ci/report-issue-hygiene.mjs \
  --fixture /path/to/issues.json \
  --as-of 2026-07-18T12:00:00Z \
  --json-output issue-hygiene-report.json
```
