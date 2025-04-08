#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
EC2_NAME_TAG="aws-cli-project-ec2"
ALARM_NAMESPACE="AWS/EC2"

# ─────────────────────────────────────────────
# Step 1: Get EC2 Instance ID
# ─────────────────────────────────────────────
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$EC2_NAME_TAG" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region $REGION)

if [[ -z "$INSTANCE_ID" ]]; then
  echo "Could not find EC2 instance with tag '$EC2_NAME_TAG'"
  exit 1
fi

echo "Found EC2 instance: $INSTANCE_ID"

# ─────────────────────────────────────────────
# Step 2: Create EC2 CPU Utilization Alarm
# ─────────────────────────────────────────────
echo "Creating EC2 CPU alarm..."

aws cloudwatch put-metric-alarm \
  --alarm-name "aws-cli-project-High-CPU" \
  --metric-name CPUUtilization \
  --namespace $ALARM_NAMESPACE \
  --statistic Average \
  --period 300 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --evaluation-periods 2 \
  --unit Percent \
  --region $REGION

echo "EC2 CPU utilization alarm created."

# ─────────────────────────────────────────────
# Step 3: Get Target Group & Load Balancer ARNs
# ─────────────────────────────────────────────
TG_ARN=$(aws elbv2 describe-target-groups \
  --names aws-cli-project-target-group \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --region $REGION)

LB_ARN=$(aws elbv2 describe-load-balancers \
  --names aws-cli-project-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text \
  --region $REGION)

LB_DIMENSION=$(echo "$LB_ARN" | awk -F':' '{print $6"/"$7}')

# ─────────────────────────────────────────────
# Step 4: Create ALB Unhealthy Host Alarm
# ─────────────────────────────────────────────
echo "Creating ELB Unhealthy Host alarm..."

aws cloudwatch put-metric-alarm \
  --alarm-name "CLITasker-Unhealthy-Hosts" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions "Name=TargetGroup,Value=$TG_ARN" "Name=LoadBalancer,Value=$LB_DIMENSION" \
  --evaluation-periods 2 \
  --region $REGION

echo "ELB Unhealthy Host alarm created."

# ─────────────────────────────────────────────
# Step 5: Output Helper
# ─────────────────────────────────────────────
echo "To view your alarms:"
echo "aws cloudwatch describe-alarms --region $REGION"