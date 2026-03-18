#!/bin/bash
# Apply Terraform components in order
# Usage: ./apply-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"

echo "=== Applying 01-alb ==="
cd "$TERRAFORM_DIR/01-alb"
terraform init
terraform apply -auto-approve

echo ""
echo "=== Applying 02-asg ==="
cd "$TERRAFORM_DIR/02-asg"
terraform init
terraform apply -auto-approve

echo ""
echo "=== Applying 03-route53 (optional - domain + HTTPS cert) ==="
cd "$TERRAFORM_DIR/03-route53"
if [ -f terraform.tfvars ]; then
  terraform init
  terraform apply -auto-approve
  CERT_ARN=$(terraform output -raw certificate_arn 2>/dev/null || true)
  if [ -n "$CERT_ARN" ]; then
    echo ""
    echo "=== Updating 01-alb with HTTPS (certificate) ==="
    cd "$TERRAFORM_DIR/01-alb"
    terraform apply -auto-approve -var="certificate_arn=$CERT_ARN"
  fi
  cd "$TERRAFORM_DIR/03-route53"
  terraform output www_url
  terraform output apex_url
else
  echo "Skipping - no terraform.tfvars. Copy terraform.tfvars.example and configure domain for HTTPS."
fi

echo ""
echo "=== Done ==="
cd "$TERRAFORM_DIR/01-alb"
terraform output alb_url
