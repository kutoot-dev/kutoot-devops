# Kutoot Architecture

## Overview

```
                    ┌─────────────────────────────────────────────────────────┐
                    │              APPLICATION LOAD BALANCER                  │
                    │              (01-alb Terraform)                         │
                    └─────────────────────────┬───────────────────────────────┘
                                              │
                    ┌─────────────────────────▼───────────────────────────────┐
                    │           EC2 AUTO SCALING GROUP (02-asg)               │
                    │           Min: 1  |  Max: 8  |  Scale on CPU            │
                    │           Laravel instances (t3.medium)                  │
                    └─────────────────────────┬───────────────────────────────┘
                                              │
                    ┌─────────────────────────▼───────────────────────────────┐
                    │           EC2 - MySQL (Self-hosted)                    │
                    │           kutoot_backend database                      │
                    └───────────────────────────────────────────────────────┘
```

## Components

| Component | Terraform | Description |
|-----------|----------|-------------|
| ALB | 01-alb | Application Load Balancer, Target Group, Listener |
| ASG | 02-asg | Launch Template, Auto Scaling Group, Laravel EC2 |
| MySQL | Manual | EC2 with self-hosted MySQL |

## Cost Estimate

| Resource | Monthly (~) |
|----------|-------------|
| 1× t3.medium (Laravel) | ₹2,800 |
| ALB | ₹1,500 |
| MySQL EC2 (t3.medium) | ₹2,800 |
| **Total** | ~₹7,100 |

## Deployment Order

1. **01-alb** - Create ALB first
2. **02-asg** - Create ASG (depends on ALB)
3. **Deploy Laravel** - On EC2 instances launched by ASG
