# One-Click Deploy: Upload code + .env to S3, then replace all instances.
# New instances will auto-deploy from S3 with full code and .env.
#
# Usage: .\deploy-complete.ps1
#        .\deploy-complete.ps1 -KutootPath "C:\path\to\kutoot"
#
# Result: All instances replaced with fresh ones running latest code + .env.
# Takes ~30-60 min. No manual SSH needed.

param(
    [string]$KutootPath = "C:\Users\aDMIN\Desktop\kutoot",
    [switch]$Wait
)

$ErrorActionPreference = "Stop"
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host ""
Write-Host "=== ONE-CLICK DEPLOY ===" -ForegroundColor Cyan
Write-Host "  New instances with full code + .env" -ForegroundColor Gray
Write-Host ""

# 1. Upload code
Write-Host "[1/3] Uploading code to S3..." -ForegroundColor Yellow
& "$ScriptDir\upload-kutoot-to-s3.ps1" -KutootPath $KutootPath
if ($LASTEXITCODE -ne 0) { exit 1 }

# 2. Upload .env
Write-Host ""
Write-Host "[2/3] Uploading .env to S3..." -ForegroundColor Yellow
& "$ScriptDir\upload-env-to-s3.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

# 3. Instance refresh
Write-Host ""
Write-Host "[3/3] Starting instance refresh (replacing all instances)..." -ForegroundColor Yellow
$TerraformDir = Join-Path (Split-Path -Parent $ScriptDir) "terraform\02-asg"
$AsgName = "kutoot-prod-asg"
if (Test-Path (Join-Path $TerraformDir "terraform.tfstate")) {
    Push-Location $TerraformDir
    try {
        $t = terraform output -raw asg_name 2>$null
        if ($t) { $AsgName = $t }
    } finally { Pop-Location }
}
$prevErr = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $result = aws autoscaling start-instance-refresh --auto-scaling-group-name $AsgName 2>&1
} finally {
    $ErrorActionPreference = $prevErr
}
if ($LASTEXITCODE -ne 0) {
    if ($result -match "InstanceRefreshInProgress") {
        Write-Host "  Instance refresh already in progress. New instances will use the code/.env you just uploaded." -ForegroundColor Yellow
    } else {
        Write-Host $result -ForegroundColor Red
        exit 1
    }
} else {
    try {
        $refresh = $result | ConvertFrom-Json
        Write-Host "  Instance Refresh ID: $($refresh.InstanceRefreshId)" -ForegroundColor Gray
    } catch {
        Write-Host "  Instance refresh started." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host ""
Write-Host "New instances will:" -ForegroundColor White
Write-Host "  - Download code from S3" -ForegroundColor Gray
Write-Host "  - Download .env from S3" -ForegroundColor Gray
Write-Host "  - Run composer, npm build, migrations" -ForegroundColor Gray
Write-Host "  - Be ready in ~10-12 min per instance" -ForegroundColor Gray
Write-Host ""
Write-Host "Total time: ~30-60 min for full refresh." -ForegroundColor Gray
Write-Host ""
Write-Host "Check status: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $AsgName --max-records 1" -ForegroundColor Gray
Write-Host ""
