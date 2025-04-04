#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
DB_IDENTIFIER="aws-cli-project-db"
DB_INSTANCE_CLASS="db.t3.micro"
DB_ENGINE="postgres"
DB_ENGINE_VERSION="17.2"
DB_ALLOCATED_STORAGE=20

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id aws-cli-project-db-password \
  --query SecretString \
  --output text \
  --region $REGION)

DB_USERNAME=$(echo "$SECRET_JSON" | jq -r .username)
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)

if [[ -z "$DB_USERNAME" || -z "$DB_PASSWORD" ]]; then
  echo "Error: Failed to retrieve DB credentials from Secrets Manager."
  exit 1
fi

# ─────────────────────────────────────────────
# Step 1: Get VPC and Subnets
# ─────────────────────────────────────────────
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=aws-cli-project-VPC" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)

RDS_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=aws-cli-project-RDS-SG" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region $REGION)

SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=aws-cli-project-PrivateSubnet-*" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region $REGION)

# Ensure at least 2 subnets are found
if [[ $(wc -w <<< "$SUBNET_IDS") -lt 2 ]]; then
  echo "Error: Less than 2 private subnets found with tag 'aws-cli-project-PrivateSubnet-*'"
  exit 1
fi

# ─────────────────────────────────────────────
# Step 2: Create DB Subnet Group
# ─────────────────────────────────────────────
echo "Creating DB Subnet Group..."

aws rds create-db-subnet-group \
  --db-subnet-group-name aws-cli-project-db-subnet-group \
  --db-subnet-group-description "Subnet group for aws-cli-project DB" \
  --subnet-ids $SUBNET_IDS \
  --region $REGION

echo "DB Subnet Group created."

# ─────────────────────────────────────────────
# Step 3: Create PostgreSQL RDS Instance
# ─────────────────────────────────────────────
echo "Launching PostgreSQL RDS instance..."

aws rds create-db-instance \
  --db-instance-identifier $DB_IDENTIFIER \
  --db-instance-class $DB_INSTANCE_CLASS \
  --engine $DB_ENGINE \
  --engine-version $DB_ENGINE_VERSION \
  --allocated-storage $DB_ALLOCATED_STORAGE \
  --master-username $DB_USERNAME \
  --master-user-password $DB_PASSWORD \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-subnet-group-name aws-cli-project-db-subnet-group \
  --no-publicly-accessible \
  --backup-retention-period 1 \
  --no-multi-az \
  --region $REGION

echo "RDS creation initiated. Waiting for it to become available..."

# ─────────────────────────────────────────────
# Step 4: Wait for RDS Availability
# ─────────────────────────────────────────────
aws rds wait db-instance-available \
  --db-instance-identifier $DB_IDENTIFIER \
  --region $REGION

# ─────────────────────────────────────────────
# Step 5: Fetch and Print DB Endpoint
# ─────────────────────────────────────────────
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_IDENTIFIER \
  --region $REGION \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

echo "PostgreSQL RDS is ready!"
echo "Endpoint: $DB_ENDPOINT"