# One-command deploy for auto-scaling: upload code + .env to S3
# New instances will auto-deploy from S3 on boot - no manual SSH needed.
#
# Run when: code changes, .env changes, or before instance refresh
# Usage: .\deploy-for-autoscale.ps1
#        .\deploy-for-autoscale.ps1 -Refresh   # Also trigger instance refresh

param(
    [switch]$Refresh
)

$ErrorActionPreference = "Stop"
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host "=== Deploy for Auto-Scale ===" -ForegroundColor Cyan
Write-Host ""

# 1. Upload code
& "$ScriptDir\upload-kutoot-to-s3.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

# 2. Upload .env
& "$ScriptDir\upload-env-to-s3.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

if ($Refresh) {
    Write-Host ""
    Write-Host ">>> Starting instance refresh..." -ForegroundColor Yellow
    aws autoscaling start-instance-refresh --auto-scaling-group-name kutoot-prod-asg
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "New instances (scale-out or refresh) will auto-deploy from S3."
