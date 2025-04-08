#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
ALB_NAME="aws-cli-project-alb"
TG_NAME="aws-cli-project-target-group"

# ─────────────────────────────────────────────
# Step 1: Get VPC and Public Subnet IDs
# ─────────────────────────────────────────────
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=aws-cli-project-VPC" \
  --query "Vpcs[0].VpcId" \
  --region $REGION \
  --output text)

SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=aws-cli-project-PublicSubnet-*" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region $REGION)

if [[ $(wc -w <<< "$SUBNET_IDS") -lt 2 ]]; then
  echo "Error: Less than 2 public subnets found with tag 'aws-cli-project-PublicSubnet-*'"
  exit 1
fi

# ─────────────────────────────────────────────
# Step 2: Create Target Group
# ─────────────────────────────────────────────
echo "Creating Target Group..."

TG_ARN=$(aws elbv2 create-target-group \
  --name $TG_NAME \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --target-type instance \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target Group ARN: $TG_ARN"

# ─────────────────────────────────────────────
# Step 3: Create ALB Security Group
# ─────────────────────────────────────────────
echo "Creating ALB Security Group..."

ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name aws-cli-project-ALB-SG \
  --description "Security group for ALB" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $REGION

aws ec2 create-tags \
  --resources $ALB_SG_ID \
  --tags Key=Name,Value=aws-cli-project-ALB-SG \
  --region $REGION

# ─────────────────────────────────────────────
# Step 4: Create ALB
# ─────────────────────────────────────────────
echo "Creating Load Balancer..."

ALB_ARN=$(aws elbv2 create-load-balancer \
  --name $ALB_NAME \
  --subnets $SUBNET_IDS \
  --security-groups $ALB_SG_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names $ALB_NAME \
  --region $REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB created: http://$ALB_DNS"

# ─────────────────────────────────────────────
# Step 5: Create Listener
# ─────────────────────────────────────────────
echo "Creating Listener..."

aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $REGION

# ─────────────────────────────────────────────
# Step 6: Register EC2 Target
# ─────────────────────────────────────────────
echo "Registering EC2 instance with Target Group..."

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aws-cli-project-ec2" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --region $REGION \
  --output text)

aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$INSTANCE_ID \
  --region $REGION

# ─────────────────────────────────────────────
# Step 7: Verify Target Health
# ─────────────────────────────────────────────
echo ""
echo "Checking target health status..."

MAX_RETRIES=20
RETRY_DELAY=10

for ((i=1; i<=MAX_RETRIES; i++)); do
  STATUS=$(aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --targets Id=$INSTANCE_ID \
    --region $REGION \
    --query 'TargetHealthDescriptions[0].TargetHealth.State' \
    --output text)

  echo "Health check attempt $i: Target status is '$STATUS'"

  if [[ "$STATUS" == "healthy" ]]; then
    echo "Target is healthy and ALB is routing properly!"
    echo "Try to visit the app at: http://$ALB_DNS"
    break
  fi

  if [[ "$i" -eq "$MAX_RETRIES" ]]; then
    echo "Target did not become healthy after $((MAX_RETRIES * RETRY_DELAY)) seconds."
    exit 1
  fi

  sleep $RETRY_DELAY
done
