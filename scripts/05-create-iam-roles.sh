#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
ROLE_NAME="aws-cli-project-ec2-role"
POLICY_NAME="aws-cli-project-ec2-policy"
SECRET_NAME="aws-cli-project-db-password"

# ─────────────────────────────────────────────
# Step 1: Detect the S3 Bucket
# ─────────────────────────────────────────────
S3_BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name, 'aws-cli-project-bucket')].Name | [0]" \
  --output text)

if [[ -z "$S3_BUCKET" || "$S3_BUCKET" == "None" ]]; then
  echo "Could not auto-detect S3 bucket. Please pass or export it manually."
  exit 1
fi

echo "Detected S3 bucket: $S3_BUCKET"

# ─────────────────────────────────────────────
# Step 2: Create Trust Policy and IAM Role
# ─────────────────────────────────────────────
echo "Creating IAM role: $ROLE_NAME..."

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json \
  --region $REGION

rm trust-policy.json

echo "IAM role created."

# ─────────────────────────────────────────────
# Step 3: Attach Inline Policy
# ─────────────────────────────────────────────
echo "Attaching inline policy to role..."

cat > policy-document.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::$S3_BUCKET",
        "arn:aws:s3:::$S3_BUCKET/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:$REGION:*:secret:$SECRET_NAME*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name $POLICY_NAME \
  --policy-document file://policy-document.json \
  --region $REGION

rm policy-document.json

echo "Inline policy attached."

# ─────────────────────────────────────────────
# Step 4: Create and Attach Instance Profile
# ─────────────────────────────────────────────
echo "Creating instance profile..."

aws iam create-instance-profile \
  --instance-profile-name $ROLE_NAME \
  --region $REGION

# Wait for instance profile to be ready
sleep 10

aws iam add-role-to-instance-profile \
  --instance-profile-name $ROLE_NAME \
  --role-name $ROLE_NAME \
  --region $REGION

echo "Instance profile ready and role attached."
