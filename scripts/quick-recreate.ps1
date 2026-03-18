# Kutoot - Full IaC Quick Recreate
# Run from: kutoot-devops root
# Usage: .\scripts\quick-recreate.ps1
# Prerequisite: terraform.tfvars in each terraform folder, AWS CLI configured
# Order: 00-mysql -> 01-alb -> 02-asg -> 03-route53 -> 01-alb (HTTPS) -> 05-s3

$ErrorActionPreference = "Stop"
$TERRAFORM_DIR = Join-Path $PSScriptRoot "..\terraform"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  KUTOOT FULL IaC - QUICK RECREATE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: terraform not found. Install Terraform first." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: aws CLI not found. Run: aws configure" -ForegroundColor Red
    exit 1
}

$runMysql = Test-Path (Join-Path $TERRAFORM_DIR "00-mysql\terraform.tfvars")
$runRoute53 = Test-Path (Join-Path $TERRAFORM_DIR "03-route53\terraform.tfvars")
$runS3 = Test-Path (Join-Path $TERRAFORM_DIR "05-s3\terraform.tfvars")

# 00-mysql (run first - creates MySQL EC2)
if ($runMysql) {
    Write-Host ">>> 00-mysql (MySQL EC2)..." -ForegroundColor Yellow
    Push-Location (Join-Path $TERRAFORM_DIR "00-mysql")
    terraform init -input=false
    terraform apply -auto-approve
    Pop-Location
    Write-Host ""
} else {
    Write-Host ">>> 00-mysql skipped (no terraform.tfvars, using existing MySQL)" -ForegroundColor Gray
}

# 01-alb
Write-Host ">>> 01-alb (ALB + Target Group)..." -ForegroundColor Yellow
Push-Location (Join-Path $TERRAFORM_DIR "01-alb")
terraform init -input=false
terraform apply -auto-approve
Pop-Location
Write-Host ""

# 02-asg (use MySQL from 00-mysql if it was run)
Write-Host ">>> 02-asg (Launch Template + ASG)..." -ForegroundColor Yellow
Push-Location (Join-Path $TERRAFORM_DIR "02-asg")
terraform init -input=false
if ($runMysql) {
    terraform apply -auto-approve -var="use_mysql_module=true"
} else {
    terraform apply -auto-approve
}
Pop-Location
Write-Host ""

# 03-route53 (optional)
if ($runRoute53) {
    Write-Host ">>> 03-route53 (DNS + HTTPS cert)..." -ForegroundColor Yellow
    Push-Location (Join-Path $TERRAFORM_DIR "03-route53")
    terraform init -input=false
    terraform apply -auto-approve
    $certArn = terraform output -raw certificate_arn 2>$null
    Pop-Location
    Write-Host ""

    if ($certArn) {
        Write-Host ">>> 01-alb (add HTTPS listener)..." -ForegroundColor Yellow
        Push-Location (Join-Path $TERRAFORM_DIR "01-alb")
        terraform apply -auto-approve -var="certificate_arn=$certArn"
        Pop-Location
        Write-Host ""
    }
} else {
    Write-Host ">>> 03-route53 skipped (no terraform.tfvars)" -ForegroundColor Gray
}

# 05-s3 (optional)
if ($runS3) {
    Write-Host ">>> 05-s3 (S3 bucket)..." -ForegroundColor Yellow
    Push-Location (Join-Path $TERRAFORM_DIR "05-s3")
    terraform init -input=false
    terraform apply -auto-approve
    Pop-Location
    Write-Host ""
} else {
    Write-Host ">>> 05-s3 skipped (no terraform.tfvars)" -ForegroundColor Gray
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  INFRASTRUCTURE READY" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Laravel instances auto-deploy via User Data (~5-10 min)" -ForegroundColor Cyan
Write-Host "Get instance IP: aws ec2 describe-instances --region ap-south-1 --filters `"Name=tag:Name,Values=kutoot-prod-laravel`" --query `"Reservations[*].Instances[*].PublicIpAddress`" --output text"
Write-Host "SSH: ssh -i kutoot-sql.pem ubuntu@<IP>"
Write-Host ""
