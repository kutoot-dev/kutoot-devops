# Pre–go-live: infra hardening (S3, ALB, MySQL)

Terraform encodes the following so you can **go public** with a stronger baseline. **Apply in order** (see your usual `01-alb` → `02-asg` flow) and run **`terraform plan`** before **`apply`**.

## What was added

### S3

| Bucket / module | Hardening |
|-----------------|-----------|
| **`05-s3`** Laravel uploads (`kutoot-backend`) | AES-256 default encryption; **Deny** all S3 API calls over **HTTP** (must use **HTTPS** URLs). Public **read** remains for `GetObject` over TLS. |
| **`02-asg`** deploy config (`.env` / tarball) | Bucket policy: **Deny** insecure transport (already had block public access + SSE). |
| **`06-mysql-backups`** | Block **all** public access; AES-256 encryption; **Deny** insecure transport. |

Ensure **`AWS_URL`** / asset URLs in Laravel use **`https://`** for S3 so browsers and SDKs stay on TLS.

### Application Load Balancer (`01-alb`)

- **`enable_deletion_protection`** (default **true**) — prevents accidental ALB delete (set **`false`** only when tearing down the stack).
- **`drop_invalid_header_fields`** — enabled.
- **`enable_alb_access_logs`** (default **true**) — writes access logs to a **private** S3 bucket (`kutoot-prod-alb-logs-<account-id>`).
- Outputs: **`alb_access_logs_bucket`**.

To disable log bucket (e.g. first apply troubleshooting): set `enable_alb_access_logs = false` in `terraform.tfvars`.

### MySQL EC2 (`00-mysql`)

- Root EBS volume: **`encrypted = true`**.
- **`metadata_options`**: **IMDSv2 required** (`http_tokens = required`).

**Warning:** Applying may **replace** or **stop/start** the instance for some changes. Plan during a **maintenance window** and ensure **backups** exist first.

### Laravel ASG (`02-asg`)

- **Launch template**: **IMDSv2 required** for new instances (matches Prowler **EC2.8**).

## Apply order (typical)

1. `terraform/01-alb` — ALB + log bucket + deletion protection  
2. `terraform/02-asg` — deploy bucket policy + launch template (then **instance refresh**)  
3. `terraform/05-s3` — Laravel uploads bucket  
4. `terraform/06-mysql-backups` — backup bucket (if not already applied)  
5. `terraform/00-mysql` — MySQL (last if risky; **plan carefully**)

## Still manual / follow-up

- **EBS default encryption** (account/region) — Console or API; see Prowler `ec2_ebs_default_encryption`.  
- **Remove public IPv4 from MySQL** — use **`associate_public_ip_address = false`** and private subnets when you can tolerate migration.  
- **WAF** on ALB — optional next step for public launch.
