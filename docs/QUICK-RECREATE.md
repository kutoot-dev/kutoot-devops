# Kutoot – Quick Recreate Runbook

**Goal:** Recreate full AWS infrastructure in ~10–15 minutes if something fails.

---

## What You Must Backup (Do This Now)

Store these in a safe place (e.g. password manager, encrypted drive, separate repo):

| Item | Location | Why |
|------|----------|-----|
| `terraform/01-alb/terraform.tfvars` | (optional – has defaults) | ALB config |
| `terraform/02-asg/terraform.tfvars` | **Critical** | Key name, MySQL SG, SSH CIDR, db_password |
| `terraform/03-route53/terraform.tfvars` | If using Route 53 | Domain config |
| `kutoot-sql.pem` | SSH key | Access EC2 instances |
| Laravel .env | /var/www/kutoot/.env | Full app config (DB, AWS, Razorpay, Mail, SMS) |
| MySQL password | Secure store | DB connection |
| AWS credentials | `~/.aws/credentials` | Terraform & CLI |

**Backup command (run from kutoot-devops root):**
```powershell
.\scripts\backup-config.ps1
```
Stores `terraform.tfvars` from each folder into `backups/config-YYYYMMDD_HHmm/`.  
**Manually store:** `kutoot-sql.pem`, MySQL password, AWS credentials, Laravel `.env` (from /var/www/kutoot/).

---

## Recreate Scenarios

### Scenario A: Only Laravel EC2 / ASG lost (ALB + MySQL OK)

**Time: ~5 min**

1. Apply ASG Terraform:
   ```powershell
   cd C:\Users\aDMIN\Desktop\kutoot-devops\terraform\02-asg
   terraform apply -auto-approve
   ```
2. Wait for new instance (2–3 min).
3. Get instance IP from EC2 console or:
   ```powershell
   aws ec2 describe-instances --region ap-south-1 --filters "Name=tag:Name,Values=kutoot-prod-laravel" --query "Reservations[*].Instances[*].PublicIpAddress" --output text
   ```
4. SSH and deploy:
   ```powershell
   ssh -i kutoot-sql.pem ubuntu@<NEW_IP>
   # On EC2: run deploy script (copy from repo or git clone kutoot-devops first)
   ./deploy-laravel-ec2.sh YOUR_MYSQL_PASSWORD
   ```

---

### Scenario B: Full infra lost (ALB + ASG + Route 53)

**Time: ~10–15 min**

**Prerequisite:** MySQL EC2 must exist (or be restored first – see Scenario C).

**Note:** The Launch Template has User Data that auto-deploys Laravel at `/var/www/kutoot` when new instances boot. Ensure `terraform/02-asg/terraform.tfvars` has `db_password` set.

1. Restore `terraform.tfvars` from backup (run from kutoot-devops root):
   ```powershell
   $b = "backups/config-YYYYMMDD_HHmm"  # use your latest backup folder
   Copy-Item "$b/terraform-01-alb.tfvars" terraform/01-alb/terraform.tfvars -ErrorAction SilentlyContinue
   Copy-Item "$b/terraform-02-asg.tfvars" terraform/02-asg/terraform.tfvars -ErrorAction SilentlyContinue
   Copy-Item "$b/terraform-03-route53.tfvars" terraform/03-route53/terraform.tfvars -ErrorAction SilentlyContinue
   ```
2. Run apply-all:
   ```powershell
   cd C:\Users\aDMIN\Desktop\kutoot-devops\scripts
   .\quick-recreate.ps1
   ```
   Or manually:
   ```powershell
   cd ..\terraform\01-alb
   terraform init
   terraform apply -auto-approve

   cd ..\02-asg
   terraform init
   terraform apply -auto-approve

   cd ..\03-route53
   terraform init
   terraform apply -auto-approve
   ```
3. Deploy Laravel (same as Scenario A, step 4).

---

### Scenario C: MySQL EC2 also lost

**Time: ~20–30 min**

1. Create new EC2 (t3.medium, Ubuntu), attach MySQL security group.
2. SSH and install MySQL, create DB, restore from backup:
   ```bash
   # Use backups/kutoot_backend_*.sql from backup-mysql.sh
   mysql -u admin -p kutoot_backend < kutoot_backend_YYYYMMDD.sql
   ```
3. Note new MySQL private IP and security group ID.
4. Update `terraform/02-asg/terraform.tfvars`:
   - `mysql_security_group_id` = MySQL EC2’s security group
5. Continue with Scenario B from step 2.

---

## Quick Reference

| Step | Command |
|------|---------|
| Apply all Terraform | `.\scripts\quick-recreate.ps1` |
| List resources | `.\scripts\aws-inventory.ps1` |
| Backup MySQL | `./backup-mysql.sh 172.31.45.181 admin ./backups` |
| Deploy Laravel | SSH to instance → `./deploy-laravel-ec2.sh PASSWORD` |

---

## Critical Values (Update if Changed)

| Setting | Current Value |
|---------|---------------|
| Region | ap-south-1 |
| MySQL IP | 172.31.45.181 |
| MySQL SG | sg-0359e25605495361d |
| SSH Key | kutoot-sql |
| DB Name | kutoot_backend |
| ALB URL | kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com |
