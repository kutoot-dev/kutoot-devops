#!/bin/bash
# Kutoot AWS Architecture Inventory
# Run: ./aws-inventory.sh
# Requires: AWS CLI configured (aws configure)

set -e
REGION="${AWS_REGION:-ap-south-1}"

echo "=========================================="
echo "  KUTOOT AWS ARCHITECTURE INVENTORY"
echo "  Region: $REGION"
echo "  Date: $(date)"
echo "=========================================="
echo ""

# EC2 Instances
echo "--- EC2 INSTANCES ---"
aws ec2 describe-instances --region $REGION \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table 2>/dev/null || echo "  (Run: aws configure)"

# Load Balancers
echo ""
echo "--- APPLICATION LOAD BALANCERS ---"
aws elbv2 describe-load-balancers --region $REGION \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName,Scheme,State.Code]' \
  --output table 2>/dev/null || true

# Target Groups
echo ""
echo "--- TARGET GROUPS ---"
aws elbv2 describe-target-groups --region $REGION \
  --query 'TargetGroups[*].[TargetGroupName,Port,Protocol,HealthCheckPath]' \
  --output table 2>/dev/null || true

# Auto Scaling Groups
echo ""
echo "--- AUTO SCALING GROUPS ---"
aws autoscaling describe-auto-scaling-groups --region $REGION \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,MinSize,MaxSize,DesiredCapacity,HealthCheckType]' \
  --output table 2>/dev/null || true

# Security Groups (kutoot-related)
echo ""
echo "--- SECURITY GROUPS (kutoot) ---"
aws ec2 describe-security-groups --region $REGION \
  --query 'SecurityGroups[?contains(GroupName, `kutoot`) || contains(GroupName, `Kutoot`)].[GroupId,GroupName,Description]' \
  --output table 2>/dev/null || true

# RDS (if any)
echo ""
echo "--- RDS DATABASES ---"
aws rds describe-db-instances --region $REGION \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Endpoint.Address,DBName]' \
  --output table 2>/dev/null || echo "  (None or no permission)"

# Route 53 Hosted Zones
echo ""
echo "--- ROUTE 53 HOSTED ZONES ---"
aws route53 list-hosted-zones \
  --query 'HostedZones[*].[Name,Id]' \
  --output table 2>/dev/null || true

# S3 Buckets (kutoot-related)
echo ""
echo "--- S3 BUCKETS (kutoot) ---"
aws s3 ls 2>/dev/null | grep -i kutoot || echo "  (None or no permission)"

# VPCs
echo ""
echo "--- VPCs ---"
aws ec2 describe-vpcs --region $REGION \
  --query 'Vpcs[*].[VpcId,IsDefault,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Run 'terraform state list' in each terraform folder for Terraform-managed resources"
echo "=========================================="
