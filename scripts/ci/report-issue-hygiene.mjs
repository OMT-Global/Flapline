#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const INACTIVE_REVIEW_DAYS = 30;
const CLOSE_OR_RESCOPE_DAYS = 90;
const MARKDOWN_SUMMARY_BYTE_LIMIT = 900 * 1024;
const NEXT_ACTION_PATTERN = /<!--\s*prs-next-action\s+([\s\S]*?)-->/gi;

function parseArgs(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (!["--fixture", "--repo", "--as-of", "--json-output"].includes(argument)) {
      throw new Error(`Unknown argument: ${argument}`);
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`${argument} requires a value.`);
    options[argument.slice(2).replace("-", "_")] = value;
    index += 1;
  }
  if (Boolean(options.fixture) === Boolean(options.repo)) {
    throw new Error("Provide exactly one of --fixture or --repo.");
  }
  return options;
}

function parseTimestamp(value, label) {
  if (typeof value !== "string") throw new Error(`${label} must be an ISO-8601 timestamp.`);
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-](\d{2}):(\d{2}))$/);
  if (!match) throw new Error(`${label} must be an ISO-8601 timestamp.`);
  const [, yearText, monthText, dayText, hourText, minuteText, secondText, zone, offsetHourText, offsetMinuteText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  const validDate = month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth[month - 1];
  const validTime = Number(hourText) <= 23 && Number(minuteText) <= 59 && Number(secondText) <= 59;
  const offsetHour = Number(offsetHourText ?? 0);
  const offsetMinute = Number(offsetMinuteText ?? 0);
  const validOffset = zone === "Z" || (offsetHour <= 14 && offsetMinute <= 59 && (offsetHour < 14 || offsetMinute === 0));
  if (!validDate || !validTime || !validOffset) throw new Error(`${label} must be an ISO-8601 timestamp.`);
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) throw new Error(`${label} must be an ISO-8601 timestamp.`);
  return timestamp;
}

function normalizeIssue(raw) {
  if (!raw || typeof raw !== "object") throw new Error("Issue records must be objects.");
  const number = raw.number;
  const title = raw.title;
  const url = raw.html_url ?? raw.url;
  const updatedAt = raw.updated_at ?? raw.updatedAt;
  if (!Number.isInteger(number) || number <= 0) throw new Error("Issue number must be a positive integer.");
  if (typeof title !== "string" || !title.trim()) throw new Error(`Issue #${number} title is required.`);
  if (typeof url !== "string" || !/^https:\/\//.test(url)) throw new Error(`Issue #${number} URL must use HTTPS.`);
  parseTimestamp(updatedAt, `Issue #${number} updatedAt`);
  return {
    number,
    title: title.replace(/\s+/g, " ").trim(),
    url,
    updatedAt,
    body: typeof raw.body === "string" ? raw.body : "",
    isPullRequest: raw.pull_request !== undefined || raw.isPullRequest === true
  };
}

function parseCheckpoint(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return Number.NaN;
  const [year, month, day] = value.split("-").map(Number);
  const timestamp = Date.UTC(year, month - 1, day);
  const parsed = new Date(timestamp);
  return parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day
    ? timestamp
    : Number.NaN;
}

function escapeMarkdownText(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\\/g, "\\\\")
    .replace(/([`*_[\]{}()#+.!|])/g, "\\$1");
}

function validEvidenceReference(value) {
  if (typeof value !== "string" || /\s/.test(value)) return false;
  if (/^(?:issue|pr|run):[1-9]\d*$/.test(value)) return true;
  try {
    const url = new URL(value);
    const publicGitHubEvidence = /^\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/(?:issues\/[1-9]\d*|pull\/[1-9]\d*|actions\/runs\/[1-9]\d*)$/.test(url.pathname);
    return url.origin === "https://github.com" && !url.username && !url.password && !url.search && !url.hash && publicGitHubEvidence;
  } catch {
    return false;
  }
}

function credibleNextAction(body, asOfTimestamp) {
  let credible;
  for (const match of body.matchAll(NEXT_ACTION_PATTERN)) {
    try {
      const value = JSON.parse(match[1]);
      const outcome = typeof value.outcome === "string" && value.outcome.trim().length > 0;
      const dependency = validEvidenceReference(value.dependency);
      const checkpoint = parseCheckpoint(value.checkpoint);
      const evidence = validEvidenceReference(value.evidence);
      if ((outcome || dependency) && Number.isFinite(checkpoint) && checkpoint > asOfTimestamp && evidence) {
        credible = { checkpoint: value.checkpoint, evidence: value.evidence };
      }
    } catch {
      // Malformed markers are not evidence and remain reportable at the normal aging threshold.
    }
  }
  return credible;
}

export function buildIssueHygieneReport(rawIssues, asOf = new Date().toISOString()) {
  const asOfTimestamp = parseTimestamp(asOf, "asOf");
  const issues = rawIssues.map(normalizeIssue).filter((issue) => !issue.isPullRequest).sort((left, right) => left.number - right.number);
  const results = [];
  let current = 0;
  let review = 0;
  let closeOrRescope = 0;

  for (const issue of issues) {
    const inactiveDays = Math.max(0, Math.floor((asOfTimestamp - parseTimestamp(issue.updatedAt, `Issue #${issue.number} updatedAt`)) / 86_400_000));
    if (inactiveDays < INACTIVE_REVIEW_DAYS) {
      current += 1;
      continue;
    }

    const nextAction = credibleNextAction(issue.body, asOfTimestamp);
    const proposedAction = inactiveDays >= CLOSE_OR_RESCOPE_DAYS && !nextAction ? "close-or-rescope" : "review";
    const humanDecisionRequired = proposedAction === "close-or-rescope";
    if (humanDecisionRequired) closeOrRescope += 1;
    else review += 1;

    results.push({
      ruleId: "PRS-ISSUE-AGING-001",
      severity: "warning",
      issue: { number: issue.number, title: issue.title, url: issue.url },
      inactiveDays,
      proposedAction,
      humanDecisionRequired,
      mutationAllowed: false,
      evidence: [
        `updatedAt=${issue.updatedAt}`,
        ...(nextAction ? [`nextActionCheckpoint=${nextAction.checkpoint}`, `nextActionEvidence=${nextAction.evidence}`] : [])
      ],
      remediation: humanDecisionRequired
        ? "A maintainer must close or rescope this issue, or record a credible evidenced next action with a future checkpoint."
        : "Review the issue and record a credible evidenced next action with a future checkpoint when work remains."
    });
  }

  return {
    schemaVersion: 1,
    asOf: new Date(asOfTimestamp).toISOString(),
    thresholds: { inactiveReviewDays: INACTIVE_REVIEW_DAYS, closeOrRescopeDays: CLOSE_OR_RESCOPE_DAYS },
    summary: { scanned: issues.length, current, review, closeOrRescope },
    results
  };
}

export function formatIssueHygieneReport(report) {
  const lines = [
    `# Issue Hygiene Report`,
    "",
    `Scanned ${report.summary.scanned} open issues: ${report.summary.current} current, ${report.summary.review} review, ${report.summary.closeOrRescope} close-or-rescope proposal(s).`,
    "",
    "This report never mutates, closes, labels, or reschedules an issue. Every close-or-rescope proposal requires a maintainer decision."
  ];
  let omitted = 0;
  for (let index = 0; index < report.results.length; index += 1) {
    const result = report.results[index];
    const entry = `- [${result.proposedAction}] [#${result.issue.number}](${result.issue.url}) ${escapeMarkdownText(result.issue.title)} — ${result.inactiveDays} inactive days; ${result.remediation}`;
    const omittedIfRejected = report.results.length - index;
    const reservedNotice = `\n\n${omittedIfRejected} additional report entries omitted from Markdown; see the complete JSON artifact.`;
    const candidate = `${[...lines, "", entry].join("\n")}${reservedNotice}\n`;
    if (Buffer.byteLength(candidate, "utf8") > MARKDOWN_SUMMARY_BYTE_LIMIT) {
      omitted = report.results.length - index;
      break;
    }
    lines.push("", entry);
  }
  if (omitted > 0) lines.push("", `${omitted} additional report entries omitted from Markdown; see the complete JSON artifact.`);
  return `${lines.join("\n")}\n`;
}

function nextPageUrl(linkHeader, repo) {
  if (!linkHeader) return undefined;
  for (const link of linkHeader.split(",")) {
    const match = link.match(/^\s*<([^>]+)>\s*;\s*rel="([^"]+)"\s*$/);
    if (match?.[2].split(/\s+/).includes("next")) {
      const url = new URL(match[1]);
      const expectedNamedPath = `/repos/${repo}/issues`;
      const isCanonicalIdPath = /^\/repositories\/\d+\/issues$/.test(url.pathname);
      if (url.origin !== "https://api.github.com" || (url.pathname !== expectedNamedPath && !isCanonicalIdPath)) {
        throw new Error("GitHub issue inventory returned an invalid next-page URL.");
      }
      return url.href;
    }
  }
  return undefined;
}

export async function fetchOpenIssues(repo, token, fetchImplementation = fetch) {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo)) throw new Error("--repo must be owner/name.");
  if (!token) throw new Error("GITHUB_TOKEN is required with --repo.");
  const issues = [];
  const visited = new Set();
  let url = `https://api.github.com/repos/${repo}/issues?state=open&per_page=100`;
  while (url) {
    if (visited.has(url)) throw new Error("GitHub issue inventory returned a pagination loop.");
    visited.add(url);
    const response = await fetchImplementation(url, {
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${token}`,
        "X-GitHub-Api-Version": "2022-11-28"
      }
    });
    if (!response.ok) throw new Error(`GitHub issue inventory failed with HTTP ${response.status}.`);
    const pageIssues = await response.json();
    if (!Array.isArray(pageIssues)) throw new Error("GitHub issue inventory returned a non-array response.");
    issues.push(...pageIssues);
    url = nextPageUrl(response.headers.get("link"), repo);
  }
  return issues;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const asOf = options.as_of ?? new Date().toISOString();
  const raw = options.fixture
    ? JSON.parse(await readFile(options.fixture, "utf8"))
    : await fetchOpenIssues(options.repo, process.env.GITHUB_TOKEN);
  const issues = Array.isArray(raw) ? raw : raw?.issues;
  if (!Array.isArray(issues)) throw new Error("Issue fixture must be an array or an object with an issues array.");
  const report = buildIssueHygieneReport(issues, asOf);
  if (options.json_output) await writeFile(options.json_output, `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(formatIssueHygieneReport(report));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
