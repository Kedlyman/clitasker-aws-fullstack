#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"

VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=aws-cli-project-VPC" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)

MY_IP=$(curl -s https://checkip.amazonaws.com)/32

# ─────────────────────────────────────────────
# Step 1: Create EC2 Security Group
# ─────────────────────────────────────────────
echo "Creating EC2 Security Group..."

EC2_SG_ID=$(aws ec2 create-security-group \
  --group-name aws-cli-project-EC2-SG \
  --description "Security group for EC2 instances" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP \
  --region $REGION

aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $REGION

aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION

echo "EC2 Security Group created: $EC2_SG_ID"

# ─────────────────────────────────────────────
# Step 2: Create RDS Security Group
# ─────────────────────────────────────────────
echo "Creating RDS Security Group..."

RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name aws-cli-project-RDS-SG \
  --description "Security group for RDS PostgreSQL" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 5432 \
  --source-group $EC2_SG_ID \
  --region $REGION

echo "RDS Security Group created: $RDS_SG_ID"

# ─────────────────────────────────────────────
# Step 3: Tag Security Groups
# ─────────────────────────────────────────────
echo "Tagging security groups..."

aws ec2 create-tags \
  --resources $EC2_SG_ID \
  --tags Key=Name,Value=aws-cli-project-EC2-SG \
  --region $REGION

aws ec2 create-tags \
  --resources $RDS_SG_ID \
  --tags Key=Name,Value=aws-cli-project-RDS-SG \
  --region $REGION

echo "Security groups created and configured successfully!"