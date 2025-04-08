#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
TIMESTAMP=$(date +%s)
BUCKET_NAME="aws-cli-project-bucket-$TIMESTAMP"
APP_TAG="CLITasker-S3"

# ─────────────────────────────────────────────
# Step 1: Create S3 Bucket
# ─────────────────────────────────────────────
echo "Creating S3 bucket: $BUCKET_NAME..."

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

echo "S3 bucket created."

# ─────────────────────────────────────────────
# Step 2: Block Public Access
# ─────────────────────────────────────────────
echo "Blocking public access on bucket..."

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Public access blocked."

# ─────────────────────────────────────────────
# Step 3: Tag the Bucket
# ─────────────────────────────────────────────
echo "Tagging bucket with Project=$APP_TAG..."

aws s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --tagging "TagSet=[{Key=Project,Value=$APP_TAG}]"

echo "Bucket tagged."

# ─────────────────────────────────────────────
# Step 4: Upload a Test File
# ─────────────────────────────────────────────
echo "Uploading test file..."

echo "CLITasker S3 bucket test file - $(date)" > test.txt
aws s3 cp test.txt s3://$BUCKET_NAME/test.txt
rm test.txt

echo "Test file uploaded."

# ─────────────────────────────────────────────
# Step 5: Output Info
# ─────────────────────────────────────────────
echo "S3 setup complete."
echo "Bucket Name: $BUCKET_NAME"
echo "This bucket is private. Access will be configured via IAM in the next script."