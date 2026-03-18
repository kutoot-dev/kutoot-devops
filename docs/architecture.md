# Kutoot Architecture

## Overview

```
                    ┌─────────────────────────────────────────────────────────┐
                    │  Route 53 (03-route53)  www.kutoot.com → ALB             │
                    └─────────────────────────┬───────────────────────────────┘
                                              │
                    ┌─────────────────────────▼───────────────────────────────┐
                    │              APPLICATION LOAD BALANCER                  │
                    │              kutoot-prod-alb (01-alb)                   │
                    └─────────────────────────┬───────────────────────────────┘
                                              │
                    ┌─────────────────────────▼───────────────────────────────┐
                    │           EC2 AUTO SCALING GROUP (02-asg)               │
                    │           kutoot-prod-asg | Min: 1 | Max: 8             │
                    │           Scale on CPU (70% out / 30% in)               │
                    │           Laravel + Nginx + PHP 8.4                    │
                    └─────────────────────────┬───────────────────────────────┘
                                              │
                    ┌─────────────────────────▼───────────────────────────────┐
                    │           EC2 - MySQL (Self-hosted)                    │
                    │           kutoot_backend database | sg-0359e25605495361d │
                    └───────────────────────────────────────────────────────┘
```

## Components

| Component | Terraform | Resource Name | Description |
|-----------|----------|---------------|-------------|
| Route 53 | 03-route53 | kutoot.com zone | DNS: www.kutoot.com, kutoot.com → ALB |
| ACM | 03-route53 | kutoot-cert | HTTPS certificate for domain |
| ALB | 01-alb | kutoot-prod-alb | Application Load Balancer, HTTP/HTTPS |
| Target Group | 01-alb | kutoot-prod-tg | Health check: /, 30s interval |
| ASG | 02-asg | kutoot-prod-asg | Launch Template + User Data (auto-deploy Laravel), 1–8 instances |
| Laravel SG | 02-asg | kutoot-prod-laravel-sg | HTTP from ALB, SSH from allowed IP |
| MySQL | Manual | EC2 | Self-hosted MySQL, kutoot_backend |

## How to Discover Your Full AWS Architecture

### 1. Run the inventory script (recommended)

```powershell
# Windows
cd C:\Users\aDMIN\Desktop\kutoot-devops\scripts
.\aws-inventory.ps1
```

```bash
# Linux/Mac
./scripts/aws-inventory.sh
```

Requires: `aws configure` with credentials for your account.

### 2. Terraform state (what Terraform manages)

```bash
cd terraform/01-alb && terraform state list
cd terraform/02-asg && terraform state list
cd terraform/03-route53 && terraform state list
```

### 3. AWS Console – quick checklist

| Service | What to check |
|---------|----------------|
| EC2 | Instances, Launch Templates |
| EC2 → Load Balancing | Load Balancers, Target Groups |
| Auto Scaling | Auto Scaling Groups |
| VPC | Security Groups, Subnets |
| Route 53 | Hosted Zones, Records |
| ACM | Certificates |

## Key Configuration (from terraform.tfvars)

| Setting | Value |
|---------|-------|
| Region | ap-south-1 (Mumbai) |
| Project | kutoot |
| Environment | prod |
| SSH Key | kutoot-sql |
| MySQL SG | sg-0359e25605495361d |
| Allowed SSH | 101.0.63.108/32 |
| ASG | Min 1, Max 8, Desired 1 |

## Cost Estimate

| Resource | Monthly (~) |
|----------|-------------|
| 1× t3.medium (Laravel) | ₹2,800 |
| ALB | ₹1,500 |
| MySQL EC2 (t3.medium) | ₹2,800 |
| **Total** | ~₹7,100 |

## Deployment Order (Full IaC)

```powershell
.\scripts\quick-recreate.ps1
```

1. **00-mysql** - MySQL EC2 (if terraform.tfvars exists)
2. **01-alb** - ALB + Target Group
3. **02-asg** - Launch Template + ASG (User Data auto-deploys Laravel)
4. **03-route53** - DNS + HTTPS cert (optional)
5. **01-alb** - Add HTTPS listener (if cert from 03-route53)
6. **05-s3** - S3 bucket for uploads (optional)

Laravel auto-deploys via User Data (~5-10 min). No manual SSH deploy needed.
