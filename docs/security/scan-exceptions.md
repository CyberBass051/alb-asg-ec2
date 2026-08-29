# Checkov Scan Exceptions

Documented suppressions for findings that are false positives or accepted risk in this project's context. Each entry states why the check doesn't apply here — review before copying this file to another project, since the reasoning is context-specific, not universal.

---

## CKV_AWS_356 / CKV_AWS_109 / CKV_AWS_111 — KMS key policy wildcard resource

**Resource:** `aws_iam_policy_document.kms_flow_logs`
**File:** `main.tf:3-39`

**Finding:** Flags `resources = ["*"]` on the root-account KMS key policy statement — CKV_AWS_356 (no wildcard resource for restrictable actions), CKV_AWS_109 (no permissions-management/resource-exposure without constraints), CKV_AWS_111 (no write access without constraints) all fire on the same statement.

**Why suppressed:** In a KMS **key policy** (attached directly to the key, evaluated as the resource-based policy), `resources = ["*"]` scopes to "this key," not "all AWS resources account-wide" — the way it would in a standalone IAM policy. Checkov's rule doesn't distinguish key-policy context from IAM-policy context, so it flags a pattern that is standard and required for KMS root-account access statements (AWS's own documentation examples use this exact shape).

**Compensating control:** The `kms:*` actions on this statement are scoped in practice to key-administration actions only (create, describe, enable/disable, tag, schedule/cancel deletion) — see the scoped-actions fix applied to `EnableRootAccountAccess`. Encrypt/decrypt operations are governed by the separate `AllowCloudWatchLogsEncryption` statement, which is principal- and condition-constrained to the CloudWatch Logs service for this account's log groups only.


**Revisit if:** this policy is ever copied into a standalone IAM policy document (not a key policy) attached to a role or user — the reasoning above does not hold in that context and the finding would be a real risk.

---

## CKV_AWS_338 — CloudWatch log retention below 1 year

**Resource:** `aws_cloudwatch_log_group.vpc_flow_logs`
**File:** `main.tf:150-158`

**Status:** Not yet decided — depends on whether this environment (`dev`) is short-lived/throwaway or a persistent account. Not suppressed pending that call.

**If suppressing for dev-only use:**
```hcl
#checkov:skip=CKV_AWS_338:Dev/test environment — short retention intentional, not a compliance-scoped account
```

**If not suppressing:** set `retention_in_days = 365` (or your organization's actual compliance minimum) instead of skipping the check.

**Revisit:** before this module is reused for a `staging` or `prod` environment — the dev justification does not carry over.

---

## AWS-0164 (Trivy) — Subnet associates public IP address

**Resource:** `aws_subnet.this["web-us-east-1a"]`, `aws_subnet.this["web-us-east-1b"]`
**File:** `modules/vpc/main.tf:75-88`

**Finding:** `map_public_ip_on_launch = true` flagged as exposing resources to the public internet by default.

**Why suppressed:** These subnets are dedicated exclusively to the internet-facing ALB, which requires a public IP to receive traffic from the internet. This is the expected, correct configuration for an internet-facing load balancer's subnet — not an accidental exposure.

**Compensating control:** No compute (EC2/ECS/other instances) is deployed into these subnets — confirmed at time of suppression. Any application/compute tier sits in separate private subnets with no public IP, reached only via the ALB's target group.

**Suppression:**
```hcl
# trivy:ignore:AWS-0164 -- Public subnet is exclusively for the internet-facing ALB, which requires a public IP to receive traffic. No compute (EC2/ECS) is deployed here.
resource "aws_subnet" "this" {
  # ...
}
```

**Revisit if:** any EC2/ECS/compute resource is ever scheduled into `web-us-east-1a/b` — at that point this subnet is no longer single-purpose and the finding becomes a real risk. Consider renaming these subnets (e.g. `alb-public-us-east-1a`) or splitting the subnet map into distinct public/private resources if this module is reused for future environments, so the ALB-only intent is enforced rather than relying on this comment.

---

## CKV2_AWS_5 — Security group not attached to another resource

Resources: aws_security_group.alb_sg (main.tf:4-15), aws_security_group.web_sg (main.tf:40-51)

Finding: Checkov's dependency graph found no reference to these security groups within the scanned file/module.

Why suppressed: Both are attached, but across a module boundary Checkov's static analysis doesn't traverse:

alb_sg → consumed as var.alb_sg_id in modules/alb/main.tf, attached to aws_lb.main_alb.security_groups.
web_sg → consumed as var.web_sg_id in modules/asg, attached via vpc_security_group_ids on aws_launch_template.web, which backs the autoscaling group.

Suppression:

hcl
#checkov:skip=CKV2_AWS_5:Attached to aws_lb.main_alb via var.alb_sg_id in the alb module — cross-module reference not visible to this scan
resource "aws_security_group" "alb_sg" {
  # ...
}

#checkov:skip=CKV2_AWS_5:Attached to aws_launch_template.web via var.web_sg_id in the asg module — cross-module reference not visible to this scan
resource "aws_security_group" "web_sg" {
  # ...
}

Revisit: not applicable — this is a structural scanner limitation (module-boundary blindness), not a temporary condition. Re-confirm the cross-module reference still exists if either module is refactored.

## CKV2_AWS_5 — vpce_sg (not suppressed — resource removed instead)

Resource: aws_security_group.vpce_sg (previously main.tf:76-87)

Status: Not suppressed. Confirmed via terraform state list | grep vpce_sg (empty output) that the resource was never applied — no state, no dependents. Commented out of the config entirely rather than suppressed, since no VPC endpoint exists yet to attach it to.

Revisit: when VPC endpoint work begins, re-add vpce_sg and attach it to the relevant aws_vpc_endpoint resource(s) at that time — don't restore this suppression as a placeholder.

---

## CKV_AWS_260 — Security group allows ingress from 0.0.0.0/0 to port 80

**Resource:** aws_security_group_rule.alb_allow_http File: main.tf:17-25

**Finding:** Port 80 open to the public internet.

**Why suppressed:** The ALB's port 80 listener (aws_lb_listener.http) performs an HTTP→HTTPS redirect only (default_action.type = "redirect", 301 to port 443) — it never forwards traffic to a target group. Public ingress on port 80 is required for clients to reach the ALB and receive the redirect; no unencrypted traffic is served past that point.

Compensating control: All actual traffic is served over the aws_lb_listener.https listener (port 443, ELBSecurityPolicy-TLS13-1-2-2021-06), which forwards to the target group. Port 80 carries no application data.

**Suppression:**

hcl
#checkov:skip=CKV_AWS_260:Port 80 is redirect-only (301 to HTTPS) — no traffic is forwarded or served unencrypted on this listener
resource "aws_security_group_rule" "alb_allow_http" {
  # ...
}

Revisit if: the port 80 listener's default_action.type is ever changed from redirect to forward — at that point this becomes a real unencrypted-traffic exposure, not a redirect entry point.

---

## CKV_AWS_150 — Load Balancer has no deletion protection enabled

**Resource:** `aws_lb.main_alb`
**File:** `modules/alb/main.tf:97-111`

**Finding:** `enable_deletion_protection = false` — the ALB can be destroyed via `terraform destroy` or the console without a manual override.

**Why suppressed:** This is a dev/test environment recreated entirely from Terraform. Accidental deletion costs a few minutes of re-apply, not data or availability loss — no user traffic, no persistent state lives on the ALB itself. Deletion protection exists to prevent costly accidental teardown of production traffic paths; that risk doesn't apply here.

**Compensating control:** Infrastructure is fully defined in Terraform (`modules/alb`) and reproducible via `terraform apply` — no manual console configuration would be lost on deletion.

**Suppression:**
\`\`\`hcl
#checkov:skip=CKV_AWS_150:Dev/test ALB, fully reproducible via Terraform — deletion protection unnecessary for a throwaway environment
\`\`\`

**Revisit if:** this module is promoted to a `staging` or `prod` environment, or reused for anything serving real traffic — at that point set `enable_deletion_protection = true` unconditionally, don't carry this suppression forward.

---

## CKV_AWS_144 — S3 bucket has no cross-region replication enabled

**Resource:** `aws_s3_bucket.alb_logs`
**File:** `modules/alb/main.tf:7-17`

**Finding:** No cross-region replication (CRR) configured on this bucket.

**Why suppressed:** This bucket stores ALB access logs only, not primary application data or state. It exists in a dev environment that is destroyed and recreated per the FinOps CD cycle. CRR protects against regional data loss for durable, non-reproducible data — access logs from a throwaway test environment don't meet that bar.

**Compensating control:** No data of lasting value lives in this bucket outside the current test cycle — losing it in a regional outage costs debugging convenience for that cycle, not application availability or persistent state.

**Suppression:**
\`\`\`hcl
#checkov:skip=CKV_AWS_144:Access-log bucket in a disposable dev environment — no durable data, CRR unnecessary
\`\`\`

**Revisit if:** this module is promoted to a `staging` or `prod` environment, or if these logs are ever repurposed for compliance/audit retention that outlives the environment itself — at that point CRR (or at minimum versioning + a retention policy) becomes a real requirement, not a nice-to-have.

---

## CKV_AWS_145 — S3 bucket not encrypted with KMS by default

**Resource:** `aws_s3_bucket.alb_logs`
**File:** `modules/alb/main.tf` (server-side encryption config)

**Finding:** Bucket uses SSE-S3 (`AES256`, AWS-managed keys) rather than SSE-KMS.

**Why suppressed:** This bucket holds ALB access logs in a disposable dev environment — no sensitive application data, no compliance requirement mandating customer-managed or AWS-KMS-managed keys. SSE-S3 already provides encryption at rest; KMS adds key-rotation control and audit trail (CloudTrail key-usage logging) that isn't warranted for throwaway log data.

**Compensating control:** Encryption at rest is enabled (AES256/SSE-S3) — data is not stored unencrypted. The gap is key-management granularity, not absence of encryption.

**Suppression:**
\`\`\`hcl
#checkov:skip=CKV_AWS_145:SSE-S3 (AES256) sufficient for disposable dev access-log bucket — KMS adds key-management overhead not warranted here
\`\`\`

**Revisit if:** this bucket ever stores anything beyond access logs, or compliance/audit requirements around key rotation and usage tracking apply — switch to SSE-KMS with a customer-managed key at that point.

---

## CKV_AWS_18 — S3 bucket has no access logging enabled

**Resource:** `aws_s3_bucket.alb_logs`
**File:** `modules/alb/main.tf:7-17`

**Why suppressed:** Same reasoning as CKV_AWS_144/CKV2_AWS_61 on this bucket — it holds ALB access logs in a disposable dev environment, torn down per FinOps cycle. Access logging would require standing up a second bucket to receive audit records of who read log files that themselves get destroyed within days. The overhead isn't proportionate to the value of the data being protected.

**Suppression:**
\`\`\`hcl
#checkov:skip=CKV_AWS_18:Disposable dev log bucket — audit trail of access to short-lived logs not proportionate to their value
\`\`\`

**Revisit if:** this bucket is promoted to persistent/prod use, or holds anything beyond ALB access logs.

---

## CKV2_AWS_28 — Public-facing ALB not protected by WAF

**Resource:** `aws_lb.main_alb`
**File:** `modules/alb/main.tf:97-111`

**Status:** Not suppressed — accepted gap for current dev/testing phase, WAF planned but not yet implemented.

**Why deferred:** WAF (AWS WAFv2 + a web ACL) adds meaningful cost and complexity that isn't justified while this ALB is only serving test traffic with no real users or attack surface exposure of consequence.

**Suppression (temporary, until implemented):**
\`\`\`hcl
#checkov:skip=CKV2_AWS_28:WAF planned but not yet implemented — dev/test phase, no production traffic
\`\`\`

**Revisit:** before this ALB serves the recruiter-facing site or any real traffic — WAF should be added at that point, not left as a permanent suppression.

---

## CKV_AWS_378 — Load Balancer target group uses HTTP protocol

**Resource:** `aws_lb_target_group.web_tg`
**File:** `modules/alb/main.tf:67-92`

**Finding:** Target group protocol is `HTTP`, not `HTTPS` — traffic from the ALB to backend instances is unencrypted.

**Why suppressed:** TLS terminates at the ALB. The public-facing listener (`aws_lb_listener.https`, port 443) handles all external HTTPS traffic and holds the ACM certificate (`ELBSecurityPolicy-TLS13-1-2-2021-06`). The ALB-to-target-group hop stays within the VPC over the private subnet — it never traverses the public internet, so this is standard TLS-termination-at-load-balancer architecture, not an unencrypted external exposure.

**Compensating control:** All traffic entering from outside the VPC is encrypted (HTTPS listener + valid ACM cert). The unencrypted leg is confined to internal VPC traffic between the ALB and its registered targets.

**Suppression:**
\`\`\`hcl
#checkov:skip=CKV_AWS_378:TLS terminates at the ALB (aws_lb_listener.https); ALB-to-target traffic stays within the VPC, not exposed externally
\`\`\`

**Revisit if:** end-to-end encryption becomes a requirement (e.g. compliance mandate, zero-trust internal networking) — at that point switch the target group to `HTTPS` and provision certificates on the backend instances as well.

---

## CKV2_AWS_61 — S3 bucket has no lifecycle configuration

**Resource:** `aws_s3_bucket.alb_logs`
**File:** `modules/alb/main.tf:7-17`

**Finding:** No lifecycle rule to transition or expire objects in this bucket.

**Why suppressed:** This bucket holds ALB access logs in a dev environment torn down per the FinOps CD cycle (rebuild → test → promote → destroy). The bucket itself has a short lifespan by design — a lifecycle policy governing object transition/expiration inside it adds no value when the whole bucket is destroyed on a similar or shorter timescale anyway.

**Compensating control:** Bucket destruction via the CD pipeline's teardown step serves the same end goal a lifecycle policy would (bounding how long log data persists) without requiring a separate lifecycle configuration.

**Suppression:**
\`\`\`hcl
#checkov:skip=CKV2_AWS_61:Disposable dev bucket torn down per CD cycle — lifecycle policy redundant given the bucket's own short lifespan
\`\`\`

**Revisit if:** this module is promoted to `staging`/`prod`, or dev stops being destroyed on a regular cycle — at that point add an actual lifecycle rule (e.g. expire logs after 30/90 days) rather than relying on manual teardown.

---

## CKV2_AWS_62 — S3 bucket has no event notifications enabled

**Resource:** `aws_s3_bucket.alb_logs`
**File:** `modules/alb/main.tf:7-17`

**Finding:** No event notification configuration (SNS/SQS/Lambda) on object creation.

**Why suppressed:** Event notifications exist to trigger downstream processing when new objects land — no such consumer exists yet for this bucket. Configuring notifications with nothing subscribed to them adds infrastructure with no function.

**Compensating control:** None currently needed — there is no pipeline consuming these logs in real time.

**Suppression:**
\`\`\`hcl
#checkov:skip=CKV2_AWS_62:No downstream consumer exists yet for log-object-created events — notification config would be dead infrastructure
\`\`\`

**Revisit if:** a log-processing pipeline is built (e.g. the stats/analytics feature planned for the recruiter site) — event notifications would then become the natural trigger mechanism for that pipeline, and this suppression should be removed in favor of an actual configuration.

---

## AWS-0053 (Trivy) — Load balancer is exposed publicly

**Resource:** `aws_lb.main_alb`
**File:** `modules/alb/main.tf:97-111`

**Finding:** `internal = false` — ALB is internet-facing.

**Why suppressed:** This ALB is intentionally public-facing — it's the entry point for the project's web traffic (currently `alb.cyberbass.live`, eventually the recruiter-facing site). Trivy's check is a general warning against *accidental* exposure, not a claim that public ALBs are inherently wrong.

**Suppression:**
\`\`\`hcl
# trivy:ignore:AWS-0053 -- Intentionally internet-facing ALB, entry point for public web traffic
resource "aws_lb" "main_alb" {
  # ...
}
\`\`\`

**Revisit:** not applicable — this is the intended, permanent architecture for this resource, not a temporary condition.

---

## AWS-0132 (Trivy) — Bucket does not encrypt data with a customer-managed key

**Resource:** `aws_s3_bucket_server_side_encryption_configuration.alb_logs`
**File:** `modules/alb/main.tf:27-35`

**Finding:** SSE-S3 (AES256, AWS-managed key) used instead of SSE-KMS with a customer-managed key.

**Why suppressed:** Same reasoning as CKV_AWS_145 on this same bucket — disposable dev environment holding ALB access logs only, no sensitive application data. SSE-S3 already encrypts at rest; the gap is key-management granularity (rotation control, usage audit trail via CloudTrail), which isn't warranted for throwaway log data in a torn-down-per-cycle environment.

**Compensating control:** Data is encrypted at rest (SSE-S3/AES256) — the finding is about key management maturity, not absence of encryption.

**Suppression:**
\`\`\`hcl
# trivy:ignore:AWS-0132 -- SSE-S3 sufficient for disposable dev access-log bucket, same reasoning as CKV_AWS_145
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  # ...
}
\`\`\`

**Revisit if:** this bucket stores anything beyond ALB access logs, or compliance/audit requirements around key rotation apply — switch to SSE-KMS with a customer-managed key.