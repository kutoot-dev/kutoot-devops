# Auto-Deploy on Scale (Fully Automated)

When the ASG auto-scales (high CPU), **new instances deploy themselves** with no manual steps. Each new instance gets:

- **Laravel code from S3** (no Git/internet needed)
- `.env` from S3 (SMS, Mail, S3, Razorpay, etc.)
- Nginx with @laravel + buffer fix (no 404 on first click)
- Node.js + `npm run build`
- Composer, migrations, permissions

## One-Time Setup

### 1. Apply Terraform

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\terraform\02-asg
terraform apply
```

This creates:
- S3 bucket (private, for .env and code tarball)
- IAM role for EC2 to read from S3
- Updated Launch Template with new User Data

**Note:** Existing instances keep running. The new config applies to **new instances only**.

### 2. Upload code and .env to S3

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\scripts
.\deploy-for-autoscale.ps1
```

This uploads:
- `kutoot.tar.gz` (from your local kutoot folder)
- `kutoot.env` (from env-templates/.env)

Run this **whenever** you change code or `env-templates/.env`.

### 3. Optional: Trigger instance refresh

```powershell
.\deploy-for-autoscale.ps1 -Refresh
```

Or manually: `aws autoscaling start-instance-refresh --auto-scaling-group-name kutoot-prod-asg`

### Fallback: Git clone

If S3 code is not found, User Data falls back to Git clone. For private repo, set in `terraform.tfvars`:

```hcl
laravel_repo_url = "https://x-access-token:TOKEN@github.com/kutoot-dev/kutoot.git"
```

## What Happens on Scale-Out

1. ASG launches new instance (high CPU alarm)
2. User Data runs on first boot (~8–12 min)
3. Instance installs Nginx, PHP, Node.js, Composer
4. **Downloads code from S3** (kutoot.tar.gz) – no Git needed
5. Downloads `.env` from S3
6. Runs `composer install`, `npm run build`, migrations
7. Instance becomes healthy → ALB sends traffic

No SSH, no manual deploy.

## Health Check Grace Period

User Data takes ~8–12 minutes. The ASG `health_check_grace_period` is 14400 (4 hours). New instances won't receive traffic until healthy.

## Update Existing Instances

Existing instances (already running) keep their current config. To apply the new setup to all:

1. **Instance Refresh** (rolling replace):
   ```bash
   aws autoscaling start-instance-refresh --auto-scaling-group-name kutoot-prod-asg
   ```
2. Or manually update each instance (SSH + deploy script).

## Verify

1. Scale ASG to 2: AWS Console → EC2 → Auto Scaling Groups → Edit → Desired = 2
2. Wait ~12 minutes
3. Check new instance log: `ssh -i kutoot-sql.pem ubuntu@<NEW_IP> "sudo tail -50 /var/log/kutoot-userdata.log"`
4. Visit `https://dev.kutoot.com` – both instances should serve traffic
