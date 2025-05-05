#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REGION="eu-central-1"
FUNCTION_NAME="aws-cli-project-daily-summary"
ROLE_NAME="aws-cli-project-lambda-role"
ZIP_FILE="lambda.zip"
RULE_NAME="daily-task-digest-rule"
USER=$(whoami)
LAMBDA_DIR="/$USER/clitasker-aws-fullstack/lambda"

echo ""
echo "Deploying Lambda function with daily trigger..."

# ─────────────────────────────────────────────
# Step 0: Detect S3 Bucket
# ─────────────────────────────────────────────
S3_BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, 'aws-cli-project-bucket')].Name | [0]" \
  --output text)

if [[ -z "$S3_BUCKET" || "$S3_BUCKET" == "None" ]]; then
  echo "Could not detect S3 bucket. Aborting."
  exit 1
fi
echo "S3 Bucket detected: $S3_BUCKET"

# ─────────────────────────────────────────────
# Step 1: Package Lambda Function
# ─────────────────────────────────────────────
echo "Packaging Lambda function code..."

if [[ ! -d "$LAMBDA_DIR" ]]; then
  echo "Lambda directory '$LAMBDA_DIR' not found. Aborting."
  exit 1
fi

cd "$LAMBDA_DIR"
zip -r "../$ZIP_FILE" . -i '*.py' >/dev/null
cd ..

if [[ ! -f "$ZIP_FILE" ]]; then
  echo "Lambda ZIP file not created. Aborting."
  exit 1
fi
echo "Lambda package created: $ZIP_FILE"

# ─────────────────────────────────────────────
# Step 2: Create IAM Role for Lambda
# ─────────────────────────────────────────────
echo "Creating IAM role for Lambda..."

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json \
  --region $REGION || echo "Role may already exist."

rm trust-policy.json

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --region $REGION || true

cat > lambda-s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::$S3_BUCKET/daily-summary/*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name "${ROLE_NAME}-S3AccessPolicy" \
  --policy-document file://lambda-s3-policy.json \
  --region $REGION

rm lambda-s3-policy.json

echo "Waiting for IAM role propagation..."
sleep 15

# ─────────────────────────────────────────────
# Step 3: Deploy Lambda Function
# ─────────────────────────────────────────────
echo "Deploying Lambda function..."

ROLE_ARN=$(aws iam get-role \
  --role-name $ROLE_NAME \
  --query 'Role.Arn' \
  --output text \
  --region $REGION)

if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &>/dev/null; then
  echo "Lambda function already exists. Updating code..."
  aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://$ZIP_FILE \
    --region $REGION

  aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --environment Variables="{S3_BUCKET=$S3_BUCKET}" \
    --region $REGION
else
  aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.11 \
    --role "$ROLE_ARN" \
    --handler handler.lambda_handler \
    --zip-file fileb://$ZIP_FILE \
    --environment Variables="{S3_BUCKET=$S3_BUCKET}" \
    --region $REGION
fi

echo "Lambda function ready: $FUNCTION_NAME"

# ─────────────────────────────────────────────
# Step 4: Schedule Lambda with EventBridge Rule
# ─────────────────────────────────────────────
echo "Creating daily EventBridge rule..."

aws events put-rule \
  --name $RULE_NAME \
  --schedule-expression "rate(1 day)" \
  --region $REGION || true

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id event-invoke-rule \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:$REGION:$ACCOUNT_ID:rule/$RULE_NAME" \
  --region $REGION || true

aws events put-targets \
  --rule $RULE_NAME \
  --targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME" \
  --region $REGION || true

# ─────────────────────────────────────────────
# Step 5: Done
# ─────────────────────────────────────────────
echo ""
echo "Lambda function scheduled daily!"
echo "Function: $FUNCTION_NAME"
echo "Trigger Rule: $RULE_NAME"
