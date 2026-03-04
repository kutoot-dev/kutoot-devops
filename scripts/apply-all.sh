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
echo "=== Done ==="
cd "$TERRAFORM_DIR/01-alb"
terraform output alb_url
