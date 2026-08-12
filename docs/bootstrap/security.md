# Public Repository Security Model

## Trust Boundaries

- Pull requests, including forks, are untrusted input. The pull-request lane runs on GitHub-hosted isolation with read-only repository permissions, does not read GitHub Actions secrets, and runs only dependency review after GitHub provisioning enables the dependency graph and sets `DEPENDENCY_REVIEW_ENABLED=true`.
- Code scanning and SBOM generation run only for trusted default-branch pushes and schedules on GitHub-hosted isolation.
- GitHub-hosted security capabilities are evaluated from a versioned capability snapshot so unsupported plan features remain distinct from repository misconfiguration.

## Required Controls

- Dependency graph, Dependabot alerts and security updates, secret scanning, push protection, code scanning, and private vulnerability reporting are required capability observations for public repositories. The dependency-graph observation must also record `dependencyReviewEnabled: true` after provisioning verifies `DEPENDENCY_REVIEW_ENABLED=true`.
- `.github/dependabot.yml` keeps both dependency and GitHub Actions pins updateable.
- `.github/workflows/security.yml` performs dependency review, CodeQL analysis for `csharp,swift`, and SPDX JSON SBOM generation using immutable action SHAs.
- `SECURITY.md` directs reporters to a private advisory and defines acknowledgement, update, remediation, and coordinated-disclosure targets.

## Fork Safety

The security workflow uses `pull_request`, never `pull_request_target`. Its top-level permission is `contents: read`; the only job reachable from a pull request uses a GitHub-hosted runner, has read-only permissions, and has no secret references. Jobs needing `security-events: write` are explicitly excluded from pull-request events.

## Capability Evidence

Capture authorized observations for these controls and pass them to `bootstrap conform --github-capabilities <path>`: `dependency-graph`, `dependabot-alerts`, `dependabot-security-updates`, `secret-scanning`, `push-protection`, `code-scanning`, and `private-vulnerability-reporting`. Record `dependencyReviewEnabled: true` only after verifying the repository activation variable. Unsupported controls remain warnings with remediation; available but disabled controls are blocking misconfigurations. Current typed exceptions may waive only their matching `github.<control>` scope.
