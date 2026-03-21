# Upload Kutoot Laravel code to S3 for auto-deploy on new ASG instances
# Run this when code changes. New instances will download from S3 (no Git needed).
#
# Prereq: terraform 02-asg applied, AWS CLI configured
# Usage: .\upload-kutoot-to-s3.ps1
#        .\upload-kutoot-to-s3.ps1 -KutootPath C:\path\to\kutoot

param(
    [string]$Bucket = "",
    [string]$KutootPath = "C:\Users\aDMIN\Desktop\kutoot"
)

$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$KutootDevopsRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))

if (-not (Test-Path (Join-Path $KutootPath "artisan"))) {
    Write-Host "ERROR: Kutoot not found at $KutootPath (no artisan)" -ForegroundColor Red
    exit 1
}

# Get bucket from terraform output if not specified
if (-not $Bucket) {
    $TerraformDir = Join-Path $KutootDevopsRoot "terraform\02-asg"
    if (-not (Test-Path (Join-Path $TerraformDir "terraform.tfstate"))) {
        Write-Host "ERROR: Run 'terraform apply' in terraform/02-asg first" -ForegroundColor Red
        exit 1
    }
    Push-Location $TerraformDir
    try {
        $Bucket = (terraform output -raw deploy_config_bucket 2>$null)
        if (-not $Bucket) { throw "deploy_config_bucket output not found" }
    } finally {
        Pop-Location
    }
}

Write-Host ">>> Creating tarball from $KutootPath..." -ForegroundColor Yellow
$ParentDir = Split-Path -Parent $KutootPath
$FolderName = Split-Path -Leaf $KutootPath
$ArchivePath = Join-Path $env:TEMP "kutoot-upload-$([guid]::NewGuid().ToString('N').Substring(0,8)).tar.gz"

Push-Location $ParentDir
try {
    tar -czf $ArchivePath --exclude=node_modules --exclude=vendor --exclude=.git $FolderName
    if ($LASTEXITCODE -ne 0) { throw "tar failed" }
} finally {
    Pop-Location
}

Write-Host ">>> Uploading to s3://$Bucket/kutoot.tar.gz" -ForegroundColor Cyan
aws s3 cp $ArchivePath "s3://$Bucket/kutoot.tar.gz" --sse AES256
Remove-Item $ArchivePath -Force -ErrorAction SilentlyContinue

Write-Host ">>> Done. New ASG instances will use this code on boot." -ForegroundColor Green
Write-Host "    Run instance refresh to apply: aws autoscaling start-instance-refresh --auto-scaling-group-name kutoot-prod-asg" -ForegroundColor Gray
