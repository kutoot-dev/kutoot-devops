# Upload env-templates/.env to S3 for auto-deploy on new ASG instances
# Run this whenever .env changes (SMS, Mail, S3, Razorpay, etc.)
#
# Prereq: terraform 02-asg applied, AWS CLI configured
# Usage: .\upload-env-to-s3.ps1
#        .\upload-env-to-s3.ps1 -Bucket kutoot-prod-deploy-config

param(
    [string]$Bucket = "",
    [string]$EnvPath = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$KutootDevopsRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))
$EnvFile = if ($EnvPath) { $EnvPath } else { Join-Path $KutootDevopsRoot "env-templates\.env" }

if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: .env not found at $EnvFile" -ForegroundColor Red
    Write-Host "Copy from env-templates\.env.example and fill in values"
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

Write-Host ">>> Uploading .env to s3://$Bucket/kutoot.env" -ForegroundColor Cyan
aws s3 cp $EnvFile "s3://$Bucket/kutoot.env" --sse AES256
Write-Host ">>> Done. New ASG instances will use this .env on boot." -ForegroundColor Green
Write-Host "    Tip: if DB_PASSWORD contains # or !, use DB_PASSWORD=`"....`" in the file (unquoted lines break .env parsing)." -ForegroundColor DarkGray
