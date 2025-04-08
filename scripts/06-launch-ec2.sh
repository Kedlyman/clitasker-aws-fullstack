#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
AMI_ID="ami-03250b0e01c28d196"  # Ubuntu Server 24.04 LTS
INSTANCE_TYPE="t2.micro"
KEY_NAME="aws-cli-project-key"
INSTANCE_NAME="aws-cli-project-ec2"
USER_DATA_FILE="user-data.sh"
KEY_PATH="$HOME/.ssh/${KEY_NAME}.pem"

# ─────────────────────────────────────────────
# Step 0: Create Key Pair (if not exists)
# ─────────────────────────────────────────────
if [[ ! -f "$KEY_PATH" ]]; then
  echo "Creating new EC2 key pair: $KEY_NAME"
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query 'KeyMaterial' \
    --output text \
    --region $REGION > "$KEY_PATH"
  chmod 400 "$KEY_PATH"
  echo "Key pair saved to $KEY_PATH"
else
  echo "Key pair already exists at $KEY_PATH"
fi

# ─────────────────────────────────────────────
# Step 1: Get Subnet & Security Group
# ─────────────────────────────────────────────
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=aws-cli-project-PublicSubnet-1" \
  --query "Subnets[0].SubnetId" \
  --region $REGION \
  --output text)

SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=aws-cli-project-EC2-SG" \
  --query "SecurityGroups[0].GroupId" \
  --region $REGION \
  --output text)

# ─────────────────────────────────────────────
# Step 2: Launch EC2 Instance
# ─────────────────────────────────────────────
echo "Launching EC2 instance..."

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --user-data file://$USER_DATA_FILE \
  --iam-instance-profile Name=aws-cli-project-ec2-role \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query 'Instances[0].InstanceId' \
  --region $REGION \
  --output text)

echo "EC2 instance launched: $INSTANCE_ID"

# ─────────────────────────────────────────────
# Step 3: Wait for Instance to Be Running
# ─────────────────────────────────────────────
echo "Waiting for EC2 to be in 'running' state..."
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID \
  --region $REGION

# ─────────────────────────────────────────────
# Step 4: Retrieve Public IP
# ─────────────────────────────────────────────
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --region $REGION \
  --output text)

echo "EC2 instance is ready!"
echo "SSH: ssh -i $KEY_PATH ubuntu@$PUBLIC_IP"