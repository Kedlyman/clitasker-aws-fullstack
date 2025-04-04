#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR_1="10.0.1.0/24"
PUBLIC_SUBNET_CIDR_2="10.0.2.0/24"
PRIVATE_SUBNET_CIDR_1="10.0.3.0/24"
PRIVATE_SUBNET_CIDR_2="10.0.4.0/24"

# ─────────────────────────────────────────────
# Step 1: Create VPC
# ─────────────────────────────────────────────
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION

echo "VPC created: $VPC_ID"

# ─────────────────────────────────────────────
# Step 2: Create Subnets
# ─────────────────────────────────────────────
echo "Creating subnets..."

PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR_1 \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR_2 \
  --availability-zone ${REGION}b \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR_1 \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR_2 \
  --availability-zone ${REGION}b \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Subnets created."
echo "Public Subnets: $PUBLIC_SUBNET_1_ID, $PUBLIC_SUBNET_2_ID"
echo "Private Subnets: $PRIVATE_SUBNET_1_ID, $PRIVATE_SUBNET_2_ID"

# ─────────────────────────────────────────────
# Step 3: Internet Gateway + Public Route Table
# ─────────────────────────────────────────────
echo "Creating Internet Gateway..."

IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID \
  --region $REGION

echo "Internet Gateway created: $IGW_ID"

echo "Creating Public Route Table..."

PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION

aws ec2 associate-route-table --route-table-id $PUBLIC_RT_ID --subnet-id $PUBLIC_SUBNET_1_ID --region $REGION
aws ec2 associate-route-table --route-table-id $PUBLIC_RT_ID --subnet-id $PUBLIC_SUBNET_2_ID --region $REGION

echo "Public route table created and associated."

# ─────────────────────────────────────────────
# Step 4: Tag Resources
# ─────────────────────────────────────────────
echo "Tagging resources..."

aws ec2 create-tags --resources $VPC_ID             --tags Key=Name,Value=aws-cli-project-VPC             --region $REGION
aws ec2 create-tags --resources $PUBLIC_SUBNET_1_ID --tags Key=Name,Value=aws-cli-project-PublicSubnet-1  --region $REGION
aws ec2 create-tags --resources $PUBLIC_SUBNET_2_ID --tags Key=Name,Value=aws-cli-project-PublicSubnet-2  --region $REGION
aws ec2 create-tags --resources $PRIVATE_SUBNET_1_ID --tags Key=Name,Value=aws-cli-project-PrivateSubnet-1 --region $REGION
aws ec2 create-tags --resources $PRIVATE_SUBNET_2_ID --tags Key=Name,Value=aws-cli-project-PrivateSubnet-2 --region $REGION
aws ec2 create-tags --resources $IGW_ID             --tags Key=Name,Value=aws-cli-project-IGW             --region $REGION
aws ec2 create-tags --resources $PUBLIC_RT_ID       --tags Key=Name,Value=aws-cli-project-PublicRT        --region $REGION

echo "VPC setup complete."
