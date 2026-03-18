# Kutoot - Quick Recreate Infrastructure
# Run from: kutoot-devops root
# Usage: .\scripts\quick-recreate.ps1
# Prerequisite: terraform.tfvars in each terraform folder, AWS CLI configured

$ErrorActionPreference = "Stop"
$TERRAFORM_DIR = Join-Path $PSScriptRoot "..\terraform"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  KUTOOT QUICK RECREATE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: terraform not found. Install Terraform first." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: aws CLI not found. Run: aws configure" -ForegroundColor Red
    exit 1
}

# 01-alb
Write-Host ">>> 01-alb (ALB + Target Group)..." -ForegroundColor Yellow
Push-Location (Join-Path $TERRAFORM_DIR "01-alb")
terraform init -input=false
terraform apply -auto-approve
Pop-Location
Write-Host ""

# 02-asg
Write-Host ">>> 02-asg (Launch Template + ASG)..." -ForegroundColor Yellow
Push-Location (Join-Path $TERRAFORM_DIR "02-asg")
terraform init -input=false
terraform apply -auto-approve
Pop-Location
Write-Host ""

# 03-route53 (optional)
$route53Tfvars = Join-Path $TERRAFORM_DIR "03-route53\terraform.tfvars"
if (Test-Path $route53Tfvars) {
    Write-Host ">>> 03-route53 (DNS + HTTPS cert)..." -ForegroundColor Yellow
    Push-Location (Join-Path $TERRAFORM_DIR "03-route53")
    terraform init -input=false
    terraform apply -auto-approve
    Pop-Location
    Write-Host ""
} else {
    Write-Host ">>> 03-route53 skipped (no terraform.tfvars)" -ForegroundColor Gray
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  INFRASTRUCTURE READY" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Deploy Laravel on new EC2 instance" -ForegroundColor Cyan
Write-Host "  1. Get instance IP: aws ec2 describe-instances --region ap-south-1 --filters `"Name=tag:Name,Values=kutoot-prod-laravel`" --query `"Reservations[*].Instances[*].PublicIpAddress`" --output text"
Write-Host "  2. ssh -i kutoot-sql.pem ubuntu@<IP>"
Write-Host "  3. Run deploy script with MySQL password"
Write-Host ""
