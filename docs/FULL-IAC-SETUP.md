# Kutoot – Full Infrastructure as Code

Everything in Terraform. Recreate in ~15–20 minutes.

## What's Included

| Module | What it creates |
|--------|-----------------|
| **00-mysql** | MySQL EC2, Security Group, User Data (install MySQL + create DB) |
| **01-alb** | ALB, Target Group, HTTP/HTTPS listeners |
| **02-asg** | Launch Template (User Data), ASG, Laravel EC2 (auto-deploy) |
| **03-route53** | Hosted zone, ACM cert, www + apex records |
| **05-s3** | S3 bucket (kutoot-backend) for uploads |

## First-Time Setup

### 1. Create terraform.tfvars in each module

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\terraform

# 00-mysql (required for full IaC)
cd 00-mysql
copy terraform.tfvars.example terraform.tfvars
# Edit: db_password, key_name, allowed_ssh_cidr

# 02-asg
cd ..\02-asg
copy terraform.tfvars.example terraform.tfvars
# Edit: db_password (must match 00-mysql), key_name

# 03-route53 (optional - for www.kutoot.com + HTTPS)
cd ..\03-route53
copy terraform.tfvars.example terraform.tfvars
# Edit: domain_name, create_hosted_zone

# 05-s3 (optional - if kutoot-backend doesn't exist)
cd ..\05-s3
copy terraform.tfvars.example terraform.tfvars
```

### 2. Run full IaC

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\scripts
.\quick-recreate.ps1
```

### 3. Wait ~15–20 minutes

- MySQL EC2: ~3 min
- Laravel instances: ~5–10 min (User Data)
- Route 53 + ACM: ~5–10 min (cert validation)

### 4. Restore MySQL data (if migrating)

```bash
# SSH to new MySQL instance
ssh -i kutoot-sql.pem ubuntu@<MYSQL_PUBLIC_IP>
mysql -u admin -p kutoot_backend < backup.sql
```

### 5. Copy .env to Laravel instance

Laravel User Data creates basic .env. For full config (Razorpay, Mail, S3, etc.):

```powershell
scp -i kutoot-sql.pem env-templates/.env.example ubuntu@<LARAVEL_IP>:/tmp/
# SSH and: cp /tmp/.env.example /var/www/kutoot/.env, then edit with real values
```

## Using Existing MySQL (skip 00-mysql)

If you already have MySQL EC2:

1. Don't create `00-mysql/terraform.tfvars`
2. In `02-asg/terraform.tfvars`: `use_mysql_module = false`, set `mysql_security_group_id` and `db_host`
3. Run `quick-recreate.ps1` – it will skip 00-mysql

## Using Existing S3 (import into Terraform)

If `kutoot-backend` bucket was created manually, import it:

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\terraform\05-s3
copy terraform.tfvars.example terraform.tfvars
terraform init
terraform import aws_s3_bucket.laravel kutoot-backend
terraform apply -auto-approve
```

This brings the bucket under Terraform (CORS, bucket policy, versioning) without recreating it.
