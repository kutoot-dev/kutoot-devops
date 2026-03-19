# Setup automated MySQL backups on the MySQL EC2 instance
# Usage: .\setup-mysql-backup.ps1 <MYSQL_IP> <MYSQL_PASSWORD> [KEY_PATH]
# Prerequisite: Run 06-mysql-backups terraform apply, attach IAM role to MySQL instance

param(
    [Parameter(Mandatory=$true)]
    [string]$MySQLIP,
    [Parameter(Mandatory=$true)]
    [string]$MySQLPassword,
    [string]$KeyPath = "C:\Users\aDMIN\Desktop\kutoot-db\kutoot-sql.pem",
    [string]$S3Bucket = "kutoot-mysql-backups",
    [string]$DbName = "kutoot_backend",
    [string]$DbUser = "admin"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $KeyPath)) {
    Write-Host "ERROR: Key not found: $KeyPath" -ForegroundColor Red
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupScript = Join-Path $ScriptDir "backup-mysql-to-s3.sh"
$SetupScript = Join-Path $ScriptDir "setup-mysql-backup-remote.sh"

# Write setup script with LF line endings to temp file (avoids CRLF from Windows)
$SetupContent = Get-Content $SetupScript -Raw
$SetupContentLf = $SetupContent -replace "`r`n", "`n" -replace "`r", "`n"
$TempSetup = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($TempSetup, $SetupContentLf, [System.Text.UTF8Encoding]::new($false))
$TempSetupName = [System.IO.Path]::GetFileName($TempSetup)

Write-Host ">>> Copying scripts to MySQL instance..." -ForegroundColor Yellow
scp -i $KeyPath $BackupScript $TempSetup "ubuntu@${MySQLIP}:~/"
ssh -i $KeyPath "ubuntu@$MySQLIP" "mv ~/$TempSetupName ~/setup-mysql-backup-remote.sh"
Remove-Item $TempSetup -Force -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ">>> Setting up backup cron on MySQL instance..." -ForegroundColor Yellow
$SshCmd = "sed -i 's/\r$//' ~/backup-mysql-to-s3.sh ~/setup-mysql-backup-remote.sh && chmod +x ~/setup-mysql-backup-remote.sh && bash ~/setup-mysql-backup-remote.sh '$DbUser' '$MySQLPassword' '$S3Bucket' '$DbName'"
ssh -i $KeyPath "ubuntu@$MySQLIP" $SshCmd
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "=== MySQL backup setup complete ===" -ForegroundColor Green
Write-Host "Backups run daily at 2 AM UTC -> s3://$S3Bucket/daily/"
Write-Host "Test manually: ssh -i $KeyPath ubuntu@$MySQLIP '~/backup-mysql-to-s3.sh $S3Bucket $DbName'"
Write-Host ""
