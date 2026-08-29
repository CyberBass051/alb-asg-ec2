# 0002 — Reserve apex domain, use a subdomain for infrastructure testing

## Status
Accepted

## Context
`cyberbass.live` will eventually host a static recruiter-facing portfolio site (S3, linking to GitHub projects) at the apex domain. In the near term, the domain is needed to test an ALB-based infrastructure project. Using the apex for the ALB test would require re-pointing it later when the recruiter site is built, causing a second disruption and forcing any external links (resume, LinkedIn) to be updated twice.

## Decision
- `alb.cyberbass.live` — Alias A record to the ALB, used for current and future infrastructure test projects.
- `cyberbass.live` (apex) — left unconfigured for now, reserved for the future recruiter-facing static site.

## Consequences
- One DNS cutover now (ADR 0001) supports both the current test project and the future site without a second migration.
- The apex currently resolves to nothing (NXDOMAIN/no answer) until the recruiter site is built — expected and not a defect.
- When the recruiter site is built, only a new Alias record at the apex is needed (pointing at S3/CloudFront) — no nameserver or subdomain changes required.
