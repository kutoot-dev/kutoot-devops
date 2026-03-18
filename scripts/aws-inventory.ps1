# Kutoot AWS Architecture Inventory (PowerShell)
# Run: .\aws-inventory.ps1
# Requires: AWS CLI configured (aws configure)

$REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "ap-south-1" }

Write-Host "=========================================="
Write-Host "  KUTOOT AWS ARCHITECTURE INVENTORY"
Write-Host "  Region: $REGION"
Write-Host "  Date: $(Get-Date)"
Write-Host "=========================================="
Write-Host ""

# EC2 Instances
Write-Host "--- EC2 INSTANCES ---"
aws ec2 describe-instances --region $REGION `
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PrivateIpAddress,Tags[?Key=='Name'].Value|[0]]" `
  --output table 2>$null; if ($LASTEXITCODE -ne 0) { Write-Host "  (Run: aws configure)" }

# Load Balancers
Write-Host ""
Write-Host "--- APPLICATION LOAD BALANCERS ---"
aws elbv2 describe-load-balancers --region $REGION `
  --query "LoadBalancers[*].[LoadBalancerName,DNSName,Scheme,State.Code]" `
  --output table 2>$null

# Target Groups
Write-Host ""
Write-Host "--- TARGET GROUPS ---"
aws elbv2 describe-target-groups --region $REGION `
  --query "TargetGroups[*].[TargetGroupName,Port,Protocol,HealthCheckPath]" `
  --output table 2>$null

# Auto Scaling Groups
Write-Host ""
Write-Host "--- AUTO SCALING GROUPS ---"
aws autoscaling describe-auto-scaling-groups --region $REGION `
  --query "AutoScalingGroups[*].[AutoScalingGroupName,MinSize,MaxSize,DesiredCapacity,HealthCheckType]" `
  --output table 2>$null

# Security Groups (kutoot-related)
Write-Host ""
Write-Host "--- SECURITY GROUPS (kutoot) ---"
aws ec2 describe-security-groups --region $REGION `
  --query "SecurityGroups[?contains(GroupName, 'kutoot') || contains(GroupName, 'Kutoot')].[GroupId,GroupName,Description]" `
  --output table 2>$null

# RDS
Write-Host ""
Write-Host "--- RDS DATABASES ---"
aws rds describe-db-instances --region $REGION `
  --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Endpoint.Address,DBName]" `
  --output table 2>$null

# Route 53
Write-Host ""
Write-Host "--- ROUTE 53 HOSTED ZONES ---"
aws route53 list-hosted-zones `
  --query "HostedZones[*].[Name,Id]" `
  --output table 2>$null

# VPCs
Write-Host ""
Write-Host "--- VPCs ---"
aws ec2 describe-vpcs --region $REGION `
  --query "Vpcs[*].[VpcId,IsDefault,CidrBlock,Tags[?Key=='Name'].Value|[0]]" `
  --output table 2>$null

Write-Host ""
Write-Host "=========================================="
Write-Host "  Run 'terraform state list' in each terraform folder for Terraform-managed resources"
Write-Host "=========================================="
