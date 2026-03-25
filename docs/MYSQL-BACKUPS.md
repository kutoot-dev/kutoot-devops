# MySQL Automated Backups

Protect your MySQL data with daily backups to S3. If the MySQL instance goes down, you can restore from S3.

## Architecture

- **S3 bucket**: `kutoot-mysql-backups` (30-day retention)
- **Daily cron**: 2 AM UTC on MySQL EC2
- **IAM role**: MySQL instance uploads dumps to S3

## Setup (One-time)

### 1. Apply Terraform (creates S3 bucket + IAM role)

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\terraform\06-mysql-backups
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply -auto-approve
```

### 2. Attach IAM role to MySQL instance

The backup IAM role includes **SSM (Session Manager)** so you can administer MySQL without a public IP.

**Preferred:** in [terraform/00-mysql](terraform/00-mysql), set `instance_profile_name = "kutoot-prod-mysql-backup-profile"` (see `terraform.tfvars.example`) and apply `00-mysql` so the instance launches with this profile.

**Manual attach (legacy):**

```powershell
$instanceId = aws ec2 describe-instances --region ap-south-1 --filters "Name=tag:Name,Values=kutoot-prod-mysql" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text

aws ec2 associate-iam-instance-profile --region ap-south-1 --instance-id $instanceId --iam-instance-profile Name=kutoot-prod-mysql-backup-profile
```

### 3. Install backup cron on MySQL instance

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\scripts
.\setup-mysql-backup.ps1 -MySQLIP 13.235.24.13 -MySQLPassword root123 -KeyPath "C:\Users\aDMIN\Desktop\kutoot-db\kutoot-sql.pem"
```

Use the instance **private IP** (or SSM port forwarding to `127.0.0.1` if MySQL listens only on private ENI). Prefer **AWS Systems Manager Session Manager** instead of SSH when the DB has no public IP.

## Verify

```bash
# SSH to MySQL instance
ssh -i kutoot-sql.pem ubuntu@13.235.24.13

# Run backup manually
~/backup-mysql-to-s3.sh kutoot-mysql-backups kutoot_backend

# Check S3
aws s3 ls s3://kutoot-mysql-backups/daily/
```

## Restore from backup

If MySQL instance is lost, restore to a new instance:

```bash
# 1. Download latest backup from S3
aws s3 cp s3://kutoot-mysql-backups/daily/kutoot_backend_20250318_020000.sql.gz ./

# 2. On new MySQL instance
gunzip kutoot_backend_20250318_020000.sql.gz
mysql -u admin -p kutoot_backend < kutoot_backend_20250318_020000.sql
```

## Future: RDS Migration

For automatic failover and managed backups, consider migrating to **Amazon RDS MySQL** with:
- Multi-AZ (automatic failover)
- Automated backups (point-in-time recovery)
- No EC2 management

This requires schema migration and updating Laravel `.env` DB_HOST.
