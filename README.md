# Kutoot DevOps

Infrastructure as Code and deployment scripts for Kutoot platform.

## Repository Structure

```
kutoot-devops/
├── terraform/
│   ├── 01-alb/          # Application Load Balancer
│   └── 02-asg/          # Auto Scaling Group (Laravel EC2)
├── scripts/
│   ├── apply-all.sh     # Apply all Terraform components
│   ├── deploy-laravel.sh
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

## Deployment Order

**Important:** Always apply in order: `01-alb` → `02-asg`

The ASG component reads outputs from ALB via Terraform remote state.

## Variables

### 01-alb
| Variable | Default | Description |
|----------|---------|-------------|
| aws_region | us-east-1 | AWS region |
| project_name | kutoot | Resource naming |
| subnet_ids | [] | Subnets (empty = default VPC) |

### 02-asg
| Variable | Required | Description |
|----------|----------|-------------|
| key_name | Yes | EC2 key pair |
| mysql_security_group_id | No | MySQL EC2 SG for DB access |
| allowed_ssh_cidr | 0.0.0.0/0 | SSH access |

## Related Repos

- **kutoot_backend** - Laravel API
- **kutpot-frontend** - Frontend (Amplify)
