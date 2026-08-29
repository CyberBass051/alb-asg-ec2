# 0003 — Dedicate the public subnet tier exclusively to the ALB

## Status
Accepted

## Context
The VPC's `web` tier subnets have `map_public_ip_on_launch = true`, flagged by Trivy (AWS-0164) as a public-exposure risk. This setting is required for an internet-facing ALB to receive traffic directly from the internet. Compute (ASG/EC2) does not need to be public and should not inherit a public IP.

## Decision
The `web` tier subnets host the ALB only. All compute (the `app` tier ASG) lives in a separate private subnet tier with no public IP assignment, reachable only through the ALB's target group.

The Trivy AWS-0164 finding is suppressed with an inline comment stating the subnet is ALB-only, and the suppression is scoped explicitly to that boundary condition.

## Consequences
- Public IP exposure is intentionally confined to the load balancer, the only resource that needs it.
- The suppression is only valid as long as no compute is ever scheduled into the `web` tier. If that changes, the finding becomes a real gap (see suppression's "revisit" condition in `docs/scan_exceptions.md`).
- Tier naming (`web` for public/ALB, `app` for private/compute) could be clearer — a future iteration might rename `web` to something like `alb-public` to make the boundary self-evident in code, not just in documentation.
