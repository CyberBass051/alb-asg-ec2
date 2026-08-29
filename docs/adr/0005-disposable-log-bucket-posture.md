# 0005 — Treat the ALB access-log bucket as disposable, not durable

## Status
Accepted

## Context
The `alb_logs` S3 bucket receives ALB access logs in a dev environment that is rebuilt and destroyed on a repeating cycle as part of a planned CD pipeline (build dev → test → promote to prod → destroy dev, for FinOps reasons). Several scanner findings (Checkov CKV_AWS_144, CKV_AWS_18, CKV2_AWS_61, CKV2_AWS_62, CKV_AWS_145; Trivy AWS-0132) treat this bucket as if it held durable, sensitive, or long-lived data — recommending cross-region replication, access logging, a lifecycle policy, event notifications, and KMS-based encryption.

## Decision
Accept these findings as non-applicable to this bucket's actual role, and suppress them with a consistent rationale: the bucket holds only ALB access logs, is not application data, and is destroyed on the same short cycle as the rest of the dev environment. SSE-S3 (AES256) is retained as the encryption mechanism rather than upgrading to SSE-KMS, since the durability/audit benefits of KMS don't apply to short-lived log data.

Each suppression is documented individually in `docs/scan_exceptions.md` with its own "revisit if" condition (promotion to a persistent environment, or repurposing the bucket for something beyond access logs).

## Consequences
- A cluster of otherwise-legitimate security/durability findings is silenced for this specific resource — this is only correct as long as the bucket's role and lifecycle stay as described above.
- If the CD pipeline's destroy-per-cycle behavior is ever removed or the bucket starts being reused across cycles, every suppression in this cluster needs re-evaluation, not just one.
- CKV2_AWS_62 (event notifications) has a concrete future trigger: if a log-analytics pipeline is later built for the recruiter site (mentioned as a possible future feature), this suppression should be revisited first, since notifications would become the natural integration point.
