# 0001 — Delegate cyberbass.live DNS to Route 53

## Status
Accepted

## Context
`cyberbass.live` was registered and DNS-managed through Squarespace, originally hosting a live Squarespace website (verified via `dig A`/`CNAME`/`NS` showing Squarespace IPs and nameservers). The domain is now intended to host AWS-based portfolio projects (ALB test environment now, a static recruiter-facing site later). No mailboxes exist on the domain (`dig MX` returned no records), and an existing SPF record (`v=spf1 -all`) already hard-fails any mail sent as this domain.

## Decision
Fully delegate the domain's nameservers from Squarespace to Route 53 (four `awsdns-*` nameservers), rather than keeping Squarespace as the authoritative DNS and delegating only a subdomain via an NS record.

Before cutover: recreate the existing SPF TXT record in the new Route 53 hosted zone to preserve the domain's anti-spoofing posture, since Route 53 delegation replaces all existing DNS records with a clean zone.

## Consequences
- All DNS for the domain — present and future subdomains — is now managed in one place (Route 53), simplifying Terraform-driven DNS/ACM automation.
- The existing Squarespace website is intentionally taken offline as part of this change; it was confirmed as no longer wanted before proceeding.
- No email is lost, since none existed on this domain.
- Future subdomain structure (see ADR 0002) does not require any further nameserver changes — only record-level changes inside the existing Route 53 zone.
