# Deploy Kutoot to new instance (no git on instance needed)
# Usage: .\deploy-to-new-instance.ps1 <INSTANCE_IP> <MYSQL_PASSWORD> [KUTOOT_PATH] [KEY_PATH] [-EnvPath PATH]
#
# Example: .\deploy-to-new-instance.ps1 3.111.42.47 root123
# With custom .env (SMS, Mail, etc.): .\deploy-to-new-instance.ps1 15.207.85.48 root123 -EnvPath "C:\path\to\.env"
#
# .env is auto-used from: env-templates/.env (your creds) or env-templates/.env.example
#
# When instance 1 goes down, dev.kutoot.com (via ALB) automatically uses instance 2.
# No manual switch needed - ALB distributes to all healthy instances.

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceIP,
    
    [Parameter(Mandatory=$true)]
    [string]$MySQLPassword,
    
    [string]$KutootPath = "C:\Users\aDMIN\Desktop\kutoot",
    [string]$KeyPath = "C:\Users\aDMIN\Desktop\kutoot-db\kutoot-sql.pem",
    [string]$EnvPath = ""
)

$ErrorActionPreference = "Stop"

# Resolve relative KeyPath to absolute
if (-not [System.IO.Path]::IsPathRooted($KeyPath)) {
    $KeyPath = (Resolve-Path $KeyPath -ErrorAction Stop).Path
}

if (-not (Test-Path $KeyPath)) {
    Write-Host "ERROR: Key not found: $KeyPath" -ForegroundColor Red
    Write-Host "Specify: .\deploy-to-new-instance.ps1 $InstanceIP $MySQLPassword -KeyPath C:\path\to\kutoot-sql.pem"
    exit 1
}

if (-not (Test-Path (Join-Path $KutootPath "artisan"))) {
    Write-Host "ERROR: Kutoot repo not found at $KutootPath (no artisan file)" -ForegroundColor Red
    Write-Host "Clone first: git clone git@github.com:kutoot-dev/kutoot.git"
    exit 1
}

Write-Host "=== Deploying Kutoot to $InstanceIP ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create tarball (exclude node_modules, vendor, .git) and SCP
Write-Host ">>> Creating deploy archive..." -ForegroundColor Yellow
$ParentDir = Split-Path -Parent $KutootPath
$FolderName = Split-Path -Leaf $KutootPath
$ArchivePath = Join-Path $env:TEMP "kutoot-deploy-$([guid]::NewGuid().ToString('N').Substring(0,8)).tar.gz"

Push-Location $ParentDir
try {
    tar -czf $ArchivePath --exclude=node_modules --exclude=vendor --exclude=.git $FolderName
    if ($LASTEXITCODE -ne 0) { throw "tar failed" }
} finally {
    Pop-Location
}

Write-Host ">>> Copying Laravel code..." -ForegroundColor Yellow
scp -i $KeyPath $ArchivePath "ubuntu@${InstanceIP}:/home/ubuntu/kutoot.tar.gz"
try { Remove-Item $ArchivePath -Force -ErrorAction SilentlyContinue } catch {}
if ($LASTEXITCODE -ne 0) { exit 1 }

# Step 2: SCP deploy script (resolve paths from script location)
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ScriptDir = [System.IO.Path]::GetFullPath($ScriptDir)
$KutootDevopsRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))
Write-Host ">>> Copying deploy script..." -ForegroundColor Yellow
scp -i $KeyPath "$ScriptDir\deploy-laravel-ec2.sh" "ubuntu@${InstanceIP}:~/"
if ($LASTEXITCODE -ne 0) { exit 1 }

# Step 2b: SCP .env to /var/www/kutoot (REQUIRED every deployment)
# Prefer: -EnvPath, then env-templates/.env, then env-templates/.env.example
$EnvFile = $EnvPath
if (-not $EnvFile) {
    $EnvCustom = Join-Path $KutootDevopsRoot "env-templates\.env"
    $EnvExample = Join-Path $KutootDevopsRoot "env-templates\.env.example"
    if (Test-Path $EnvCustom) {
        $EnvFile = $EnvCustom  # env-templates/.env has SMS, Mail, S3, Razorpay, etc.
    } elseif (Test-Path $EnvExample) {
        $EnvFile = $EnvExample
    }
}

if (-not $EnvFile -or -not (Test-Path $EnvFile)) {
    Write-Host "ERROR: No .env file found." -ForegroundColor Red
    Write-Host "  Create one at: $KutootDevopsRoot\env-templates\.env" -ForegroundColor Yellow
    Write-Host "  Or copy from:  env-templates\.env.example" -ForegroundColor Yellow
    Write-Host "  Or specify:    -EnvPath ""C:\path\to\.env""" -ForegroundColor Yellow
    exit 1
}

Write-Host ">>> Copying .env ($(Split-Path -Leaf $EnvFile))..." -ForegroundColor Yellow
scp -i $KeyPath $EnvFile "ubuntu@${InstanceIP}:~/.env.deploy"
if ($LASTEXITCODE -ne 0) { exit 1 }

# Step 3: SSH, extract tarball, and run deploy
Write-Host ">>> Running deploy on instance..." -ForegroundColor Yellow
$SshCommands = @(
    "cd /home/ubuntu && tar -xzf kutoot.tar.gz && rm kutoot.tar.gz",
    "sed -i 's/\r$//' deploy-laravel-ec2.sh && chmod +x deploy-laravel-ec2.sh",
    "./deploy-laravel-ec2.sh $MySQLPassword"
) -join " && "
ssh -i $KeyPath "ubuntu@$InstanceIP" $SshCommands
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Instance ready. ALB will send traffic when healthy."
Write-Host "dev.kutoot.com uses ALB - no manual switch needed."
