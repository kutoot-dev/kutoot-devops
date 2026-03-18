# Kutoot - Complete AWS Backend Inventory
# Run: .\aws-full-inventory.ps1
# Output: Console + docs/BACKEND-INVENTORY.md + backups/aws-inventory-YYYYMMDD.json
# Requires: AWS CLI configured (aws configure)

$REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "ap-south-1" }
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$REPO_ROOT = Split-Path -Parent $SCRIPT_DIR
$BACKUP_DIR = Join-Path $REPO_ROOT "backups"
$DOCS_DIR = Join-Path $REPO_ROOT "docs"
$timestamp = Get-Date -Format "yyyyMMdd_HHmm"

New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

$output = @()
$output += "=========================================="
$output += "  KUTOOT AWS BACKEND - COMPLETE INVENTORY"
$output += "  Region: $REGION"
$output += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$output += "=========================================="
$output += ""

# Check AWS CLI
try {
    $null = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI not configured" }
    $account = aws sts get-caller-identity --query Account --output text 2>$null
    $output += "AWS Account: $account"
    $output += ""
} catch {
    $output += "ERROR: AWS CLI not configured. Run: aws configure"
    $output += ""
    $output | Out-File (Join-Path $DOCS_DIR "BACKEND-INVENTORY.md") -Encoding UTF8
    Write-Host $output
    exit 1
}

# --- EC2 INSTANCES (full details) ---
$output += "--- EC2 INSTANCES ---"
$instancesRaw = aws ec2 describe-instances --region $REGION --output json 2>$null
if ($instancesRaw) {
    $instancesData = $instancesRaw | ConvertFrom-Json
    foreach ($res in $instancesData.Reservations) {
        foreach ($inst in $res.Instances) {
            $name = ($inst.Tags | Where-Object { $_.Key -eq "Name" }).Value
            $output += "  InstanceId: $($inst.InstanceId)"
            $output += "  Name: $name"
            $output += "  State: $($inst.State.Name)"
            $output += "  Type: $($inst.InstanceType)"
            $output += "  Private IP: $($inst.PrivateIpAddress)"
            $output += "  Public IP: $($inst.PublicIpAddress)"
            $output += "  KeyName: $($inst.KeyName)"
            $output += "  LaunchTime: $($inst.LaunchTime)"
            $sgIds = ($inst.SecurityGroups | ForEach-Object { $_.GroupId }) -join ", "
            $output += "  SecurityGroups: $sgIds"
            $output += ""
        }
    }
}

# --- LOAD BALANCERS ---
$output += "--- APPLICATION LOAD BALANCERS ---"
$albsRaw = aws elbv2 describe-load-balancers --region $REGION --output json 2>$null
$albs = if ($albsRaw) { ($albsRaw | ConvertFrom-Json).LoadBalancers } else { @() }
foreach ($alb in $albs) {
    $output += "  Name: $($alb.LoadBalancerName)"
    $output += "  DNSName: $($alb.DNSName)"
    $output += "  ARN: $($alb.LoadBalancerArn)"
    $output += "  Scheme: $($alb.Scheme)"
    $output += "  State: $($alb.State.Code)"
    $output += ""
}

# --- TARGET GROUPS ---
$output += "--- TARGET GROUPS ---"
$tgs = aws elbv2 describe-target-groups --region $REGION --output json 2>$null | ConvertFrom-Json
foreach ($tg in $tgs.TargetGroups) {
    $output += "  Name: $($tg.TargetGroupName)"
    $output += "  ARN: $($tg.TargetGroupArn)"
    $output += "  Port: $($tg.Port)"
    $output += "  HealthCheck: $($tg.HealthCheckPath) (interval $($tg.HealthCheckIntervalSeconds)s)"
    $output += ""
}

# --- ALB LISTENERS ---
$output += "--- ALB LISTENERS ---"
foreach ($alb in $albs) {
    $listeners = aws elbv2 describe-listeners --load-balancer-arn $alb.LoadBalancerArn --region $REGION --output json 2>$null | ConvertFrom-Json
    foreach ($l in $listeners.Listeners) {
        $output += "  Port: $($l.Port) Protocol: $($l.Protocol)"
        $output += ""
    }
}

# --- AUTO SCALING GROUPS ---
$output += "--- AUTO SCALING GROUPS ---"
$asgs = aws autoscaling describe-auto-scaling-groups --region $REGION --output json 2>$null | ConvertFrom-Json
foreach ($asg in $asgs.AutoScalingGroups) {
    if ($asg.AutoScalingGroupName -like "*kutoot*") {
        $output += "  Name: $($asg.AutoScalingGroupName)"
        $output += "  Min: $($asg.MinSize) Max: $($asg.MaxSize) Desired: $($asg.DesiredCapacity)"
        $output += "  HealthCheckType: $($asg.HealthCheckType)"
        $output += "  HealthCheckGracePeriod: $($asg.HealthCheckGracePeriod) seconds"
        $output += "  LaunchTemplate: $($asg.LaunchTemplateId)"
        $output += "  TargetGroups: $(($asg.TargetGroupARNs) -join ', ')"
        $output += ""
    }
}

# --- SECURITY GROUPS (kutoot) ---
$output += "--- SECURITY GROUPS (kutoot) ---"
$sgs = aws ec2 describe-security-groups --region $REGION --query "SecurityGroups[?contains(GroupName, 'kutoot')]" --output json 2>$null | ConvertFrom-Json
foreach ($sg in $sgs) {
    $output += "  $($sg.GroupId) - $($sg.GroupName)"
    $output += "  Description: $($sg.Description)"
    foreach ($rule in $sg.IpPermissions) {
        $output += "    Inbound: $($rule.FromPort)-$($rule.ToPort) $($rule.IpProtocol)"
    }
    $output += ""
}

# --- ROUTE 53 ---
$output += "--- ROUTE 53 (kutoot.com) ---"
$zonesRaw = aws route53 list-hosted-zones --output json 2>$null | ConvertFrom-Json
$zones = $zonesRaw.HostedZones | Where-Object { $_.Name -like "*kutoot*" }
foreach ($zone in $zones) {
    $output += "  Zone: $($zone.Name) ID: $($zone.Id)"
    $records = aws route53 list-resource-record-sets --hosted-zone-id $zone.Id --output json 2>$null | ConvertFrom-Json
    foreach ($r in $records.ResourceRecordSets) {
        if ($r.Type -match "A|CNAME|AAAA") {
            $target = if ($r.AliasTarget) { $r.AliasTarget.DNSName } else { ($r.ResourceRecords.Value -join ", ") }
            $output += "    $($r.Name) $($r.Type) -> $target"
        }
    }
    $output += ""
}

# --- VPC ---
$output += "--- VPC ---"
$vpcs = aws ec2 describe-vpcs --region $REGION --output json 2>$null | ConvertFrom-Json
foreach ($vpc in $vpcs.Vpcs) {
    $output += "  $($vpc.VpcId) $($vpc.CidrBlock) Default: $($vpc.IsDefault)"
}
$output += ""

# --- KEY CONFIG (for quick reference) ---
$output += "--- QUICK REFERENCE ---"
$output += "  Laravel path: /var/www/kutoot"
$output += "  MySQL host: 172.31.45.181"
$output += "  DB name: kutoot_backend"
$output += "  ALB URL: kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com"
$output += "  dev.kutoot.com: Cloudflare (not Route 53)"
$output += ""
$output += "=========================================="

# Save to docs
$output | Out-File (Join-Path $DOCS_DIR "BACKEND-INVENTORY.md") -Encoding UTF8

# Export JSON backup
$instancesRawForJson = aws ec2 describe-instances --region $REGION --output json 2>$null
$jsonOutput = @{
    timestamp = Get-Date -Format "o"
    region = $REGION
    account = $account
    inventory = $output -join "`n"
} | ConvertTo-Json -Depth 5
$jsonOutput | Out-File (Join-Path $BACKUP_DIR "aws-inventory-$timestamp.json") -Encoding UTF8

# Console output
Write-Host $output
Write-Host ""
Write-Host "Saved to: docs/BACKEND-INVENTORY.md" -ForegroundColor Green
Write-Host "Backup:   backups/aws-inventory-$timestamp.json" -ForegroundColor Green
