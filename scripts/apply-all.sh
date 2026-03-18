#!/bin/bash
# Kutoot - Full IaC Apply (run in order)
# Usage: ./apply-all.sh
# Order: 00-mysql -> 01-alb -> 02-asg -> 03-route53 -> 01-alb (HTTPS) -> 05-s3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"

echo "=== Kutoot Full IaC Apply ==="

# 00-mysql
if [ -f "$TERRAFORM_DIR/00-mysql/terraform.tfvars" ]; then
  echo ">>> 00-mysql (MySQL EC2)"
  cd "$TERRAFORM_DIR/00-mysql"
  terraform init -input=false
  terraform apply -auto-approve
  echo ""
fi

# 01-alb
echo ">>> 01-alb (ALB + Target Group)"
cd "$TERRAFORM_DIR/01-alb"
terraform init -input=false
terraform apply -auto-approve
echo ""

# 02-asg
echo ">>> 02-asg (Launch Template + ASG)"
cd "$TERRAFORM_DIR/02-asg"
terraform init -input=false
if [ -f "$TERRAFORM_DIR/00-mysql/terraform.tfvars" ]; then
  terraform apply -auto-approve -var="use_mysql_module=true"
else
  terraform apply -auto-approve
fi
echo ""

# 03-route53
if [ -f "$TERRAFORM_DIR/03-route53/terraform.tfvars" ]; then
  echo ">>> 03-route53 (DNS + HTTPS cert)"
  cd "$TERRAFORM_DIR/03-route53"
  terraform init -input=false
  terraform apply -auto-approve
  CERT_ARN=$(terraform output -raw certificate_arn 2>/dev/null || true)
  if [ -n "$CERT_ARN" ]; then
    echo ">>> 01-alb (add HTTPS listener)"
    cd "$TERRAFORM_DIR/01-alb"
    terraform apply -auto-approve -var="certificate_arn=$CERT_ARN"
  fi
  cd "$TERRAFORM_DIR/03-route53"
  terraform output www_url 2>/dev/null || true
  terraform output apex_url 2>/dev/null || true
  echo ""
fi

# 05-s3
if [ -f "$TERRAFORM_DIR/05-s3/terraform.tfvars" ]; then
  echo ">>> 05-s3 (S3 bucket)"
  cd "$TERRAFORM_DIR/05-s3"
  terraform init -input=false
  terraform apply -auto-approve
  echo ""
fi

echo "=== Done ==="
cd "$TERRAFORM_DIR/01-alb"
terraform output alb_url
