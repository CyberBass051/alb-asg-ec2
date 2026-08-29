# 0004 — Terminate TLS at the ALB; internal ALB-to-target traffic stays HTTP

## Status
Accepted

## Context
Checkov (CKV_AWS_378) and equivalent scanners flag the `web_tg` target group for using HTTP rather than HTTPS between the ALB and backend instances. The ALB itself terminates TLS on its public listener (port 443, ACM-issued certificate, `ELBSecurityPolicy-TLS13-1-2-2021-06`) and redirects all port-80 traffic to HTTPS (no forwarding on port 80).

## Decision
TLS terminates at the ALB. The ALB-to-target-group hop remains plain HTTP, since that traffic never leaves the VPC and stays within a private subnet, not the public internet.

The public HTTP listener (port 80) performs a 301 redirect to HTTPS only — it never forwards traffic to a target group, so no unencrypted traffic reaches an actual application, and public port-80 exposure (flagged separately by CKV_AWS_260) is limited to serving that redirect.

## Consequences
- Simpler certificate management: a single ACM certificate on the ALB, no certificates needed on individual instances.
- The ALB-to-instance hop is unencrypted at the packet level, though confined to internal VPC traffic — acceptable for this environment's threat model.
- If end-to-end encryption becomes a requirement (e.g. compliance driven), the target group protocol would need to change to HTTPS with certificates provisioned on each instance — a more complex certificate-rotation problem than the current single-ALB-certificate setup.
