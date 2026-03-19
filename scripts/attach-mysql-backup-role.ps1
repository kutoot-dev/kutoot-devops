# Attach IAM backup role to MySQL EC2 instance
# Run after: terraform apply in 06-mysql-backups
# Usage: .\attach-mysql-backup-role.ps1
#        .\attach-mysql-backup-role.ps1 -InstanceId i-0ed31769c418663cb
#        .\attach-mysql-backup-role.ps1 -PublicIP 13.235.24.13

param(
    [string]$InstanceId = "",
    [string]$PublicIP = "",
    [string]$ProfileName = "kutoot-prod-mysql-backup-profile",
    [string]$Region = "ap-south-1"
)

$ErrorActionPreference = "Stop"

if (-not $InstanceId) {
    Write-Host ">>> Fetching MySQL instance ID..." -ForegroundColor Yellow
    if ($PublicIP) {
        $InstanceId = aws ec2 describe-instances --region $Region `
            --filters "Name=ip-address,Values=$PublicIP" "Name=instance-state-name,Values=running" `
            --query "Reservations[0].Instances[0].InstanceId" --output text
    }
    if (-not $InstanceId -or $InstanceId -eq "None") {
        $InstanceId = aws ec2 describe-instances --region $Region `
            --filters "Name=tag:Name,Values=kutoot-prod-mysql" "Name=instance-state-name,Values=running" `
            --query "Reservations[0].Instances[0].InstanceId" --output text
    }
    if (-not $InstanceId -or $InstanceId -eq "None") {
        $InstanceId = aws ec2 describe-instances --region $Region `
            --filters "Name=tag:Name,Values=kutoot-mysql" "Name=instance-state-name,Values=running" `
            --query "Reservations[0].Instances[0].InstanceId" --output text
    }
    if (-not $InstanceId -or $InstanceId -eq "None") {
        Write-Host "ERROR: No MySQL instance found. Try:" -ForegroundColor Red
        Write-Host "  .\attach-mysql-backup-role.ps1 -InstanceId i-xxxxxxxxx" -ForegroundColor Yellow
        Write-Host "  .\attach-mysql-backup-role.ps1 -PublicIP 13.235.24.13" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "List instances: aws ec2 describe-instances --region $Region --query `"Reservations[*].Instances[*].[InstanceId,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]`" --output table"
        exit 1
    }
}

Write-Host ">>> Attaching IAM profile to $InstanceId..." -ForegroundColor Yellow
aws ec2 associate-iam-instance-profile --region $Region `
    --instance-id $InstanceId `
    --iam-instance-profile Name=$ProfileName

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "MySQL instance can now upload backups to S3."
Write-Host "Next: Run .\setup-mysql-backup.ps1 to install backup cron"
Write-Host ""
