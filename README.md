# Kutoot DevOps

Infrastructure as Code and deployment scripts for Kutoot platform.

## Repository Structure

```
kutoot-devops/
├── terraform/
│   ├── 00-mysql/        # MySQL EC2 (run first)
│   ├── 01-alb/          # Application Load Balancer
│   ├── 02-asg/          # Auto Scaling Group (Laravel EC2 + User Data)
│   ├── 03-route53/      # Route 53 DNS (www.kutoot.com)
│   └── 05-s3/           # S3 bucket (kutoot-backend)
├── scripts/
│   ├── apply-all.sh       # Apply all Terraform (bash)
│   ├── quick-recreate.ps1 # Recreate infra (PowerShell)
│   ├── backup-config.ps1  # Backup terraform.tfvars
│   ├── aws-inventory.ps1  # List AWS resources
│   ├── deploy-laravel-ec2.sh
│   └── backup-mysql.sh
├── docs/
│   └── architecture.md
└── README.md
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured
- EC2 key pair in AWS

## Quick Start

### 1. Deploy ALB (Component 1)

```bash
cd terraform/01-alb
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

### 2. Deploy ASG (Component 2)

```bash
cd terraform/02-asg
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - set key_name, mysql_security_group_id
terraform init
terraform plan
terraform apply
```

### 3. Get ALB URL

```bash
cd terraform/01-alb
terraform output alb_url
```

## Deployment Order (Full IaC)

**One command:** `.\scripts\quick-recreate.ps1`

Order: `00-mysql` → `01-alb` → `02-asg` → `03-route53` → `01-alb` (HTTPS) → `05-s3`

- Copy `terraform.tfvars.example` to `terraform.tfvars` in each folder
- Set `db_password` in 00-mysql and 02-asg
- Laravel auto-deploys via User Data on new instances

## Domain + HTTPS Setup (www.kutoot.com)

To point www.kutoot.com to your ALB **with HTTPS**:

```bash
cd terraform/03-route53
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - set domain_name, create_hosted_zone or route53_zone_id
terraform init
terraform plan
terraform apply
```

Then update the ALB with the certificate (or use `./scripts/apply-all.sh` which does this automatically):

```bash
cd terraform/01-alb
terraform apply -var="certificate_arn=$(cd ../03-route53 && terraform output -raw certificate_arn)"
```

**If creating a new hosted zone:** After apply, copy the `name_servers` output and update your domain registrar (GoDaddy, Namecheap, etc.) to use those nameservers. DNS propagation can take up to 48 hours. ACM certificate validation also uses DNS and may take 5–30 minutes.

**If using existing Route 53 zone:** Set `create_hosted_zone = false` and `route53_zone_id = "Z0..."` in terraform.tfvars.

**Result:** `https://www.kutoot.com` and `https://kutoot.com` → ALB → Laravel backend. HTTP redirects to HTTPS.

**Later (frontend):** To route traffic to Amplify frontend, add ALB listener rules (path-based or host-based) or use CloudFront in front of ALB + Amplify.

## Variables

### 01-alb
| Variable | Default | Description |
|----------|---------|-------------|
| aws_region | ap-south-1 | AWS region |
| project_name | kutoot | Resource naming |
| subnet_ids | [] | Subnets (empty = default VPC) |

### 02-asg
| Variable | Required | Description |
|----------|----------|-------------|
| key_name | Yes | EC2 key pair |
| mysql_security_group_id | No | MySQL EC2 SG for DB access |
| allowed_ssh_cidr | 0.0.0.0/0 | SSH access |

### 03-route53
| Variable | Default | Description |
|----------|---------|-------------|
| domain_name | (required) | Root domain (e.g. kutoot.com) |
| create_hosted_zone | false | Create new Route 53 zone |
| route53_zone_id | "" | Existing zone ID (if not creating) |
| create_apex_record | true | Also create kutoot.com → ALB |

Creates ACM certificate for HTTPS (kutoot.com + www.kutoot.com) with DNS validation.

### 01-alb (HTTPS)
| Variable | Default | Description |
|----------|---------|-------------|
| certificate_arn | "" | ACM cert ARN. When set: HTTPS listener + HTTP→HTTPS redirect |

## Backend Inventory (run after AWS CLI setup)

```powershell
.\scripts\aws-full-inventory.ps1
```

Creates `docs/BACKEND-INVENTORY.md` with complete AWS resource list. Run weekly or after changes. See [docs/AWS-CLI-SETUP.md](docs/AWS-CLI-SETUP.md).

## Disaster Recovery / Quick Recreate

If infrastructure is lost, recreate in ~10–15 minutes:

1. **Backup config now:** `.\scripts\backup-config.ps1` (stores terraform.tfvars)
2. **Store separately:** `kutoot-sql.pem`, MySQL password, AWS credentials
3. **Recreate:** `.\scripts\quick-recreate.ps1`

See **[docs/QUICK-RECREATE.md](docs/QUICK-RECREATE.md)** for full runbook and scenarios.

## Laravel Instance Setup

One-shot setup on a fresh Ubuntu 22.04 instance:

```bash
git clone git@github.com:sanjeev059/kutoot-devops.git
cd kutoot-devops/scripts
./deploy-laravel-ec2.sh YOUR_MYSQL_PASSWORD
```

See **[docs/INSTANCE-DEPENDENCIES.md](docs/INSTANCE-DEPENDENCIES.md)** for full environment details.

## Related Repos

- **kutoot** - Laravel API — `git clone git@github.com:kutoot-dev/kutoot.git` (branch: main)
- **kutpot-frontend** - Frontend (Amplify)
