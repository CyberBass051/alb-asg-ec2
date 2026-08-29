# 0006 — Use a persistent NAT Gateway instead of an ephemeral-NAT + Packer + VPC-endpoint pipeline

## Status
Accepted (supersedes an initial plan, documented below for the record)

## Context
The `app`-tier ASG instances live in a private subnet and need outbound internet access to install Apache and OS packages at boot, and to reach AWS's public SSM/CloudWatch endpoints for management and observability.

Two architectures were evaluated:

**Option A (initially planned):** Bake Apache into a custom AMI using Packer, run in a temporary public subnet with a NAT Gateway created only for the duration of the build and destroyed immediately after. At runtime, ASG instances would use persistent VPC interface endpoints (SSM, SSMMESSAGES, EC2MESSAGES) for management access instead of NAT, avoiding an always-on NAT Gateway.

**Option B (adopted):** Skip Packer entirely; install Apache via a `user_data` script at instance boot, same as before Packer was considered. Keep a single, persistent NAT Gateway for all outbound needs — package installation at boot, ongoing OS updates, and SSM/CloudWatch access — for the life of the environment.

Cost comparison (list pricing, single NAT vs. 3 SSM endpoints across 2 AZs): a persistent NAT Gateway (~$32–33/month) was found to be roughly comparable to, or cheaper than, always-on dual-AZ interface endpoints (~$43/month) for this project's low rebuild frequency — meaning Option A's cost-optimization premise did not hold up under actual pricing for this specific access pattern.

## Decision
Adopt Option B: persistent NAT Gateway, single-AZ (no cross-AZ redundancy, since this environment carries no production traffic and an AZ outage costing a few hours of NAT downtime is an acceptable risk here). No Packer pipeline, no VPC interface endpoints for SSM.

## Consequences
- Significantly less operational complexity: no AMI-build pipeline, no cross-tool (Packer + Terraform) AMI-ID handoff, no conditional infrastructure toggling between build and runtime states.
- NAT Gateway now serves an ongoing purpose (SSM, CloudWatch, package updates) rather than only a one-time bootstrap need — this is a stronger justification for its persistent cost than "just for installing Apache."
- The original cost-optimization goal behind the ephemeral-NAT idea is not achieved by this decision; it is explicitly traded away in favor of build simplicity, given this is a portfolio/learning project with limited time investment, not a cost-sensitive production workload.
- Single-AZ NAT placement means an AZ outage removes outbound access for `app`-tier instances in the unaffected AZ as well (NAT Gateway is not shared across AZs) — accepted here, would need per-AZ NAT Gateways in a production-grade version of this architecture.