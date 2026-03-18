# Backup critical config for disaster recovery
# Run from: kutoot-devops root
# Usage: .\scripts\backup-config.ps1

$ErrorActionPreference = "Stop"
$BACKUP_DIR = Join-Path $PSScriptRoot "..\backups"
$timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$dest = Join-Path $BACKUP_DIR "config-$timestamp"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "Backing up config to $dest" -ForegroundColor Cyan

$copied = $false
foreach ($dir in @("01-alb", "02-asg", "03-route53")) {
    $src = Join-Path $PSScriptRoot "..\terraform\$dir\terraform.tfvars"
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $dest "terraform-$dir.tfvars")
        Write-Host "  Copied: terraform/$dir/terraform.tfvars" -ForegroundColor Green
        $copied = $true
    }
}

if ($copied) {
    Write-Host ""
    Write-Host "Done. Store kutoot-sql.pem and MySQL password separately!" -ForegroundColor Yellow
} else {
    Write-Host "No terraform.tfvars found." -ForegroundColor Gray
}
