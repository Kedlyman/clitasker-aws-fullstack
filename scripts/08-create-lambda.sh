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

# ─────────────────────────────────────────────
# Step 1: Package Lambda Function
# ─────────────────────────────────────────────
echo "Packaging Lambda function..."

cd ~/aws-cli-project/lambda
zip -r ../$ZIP_FILE . -i '*.py'
cd ..

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
  --region $REGION

rm trust-policy.json

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --region $REGION

echo "Waiting for IAM role to propagate..."
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

aws lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.11 \
  --role "$ROLE_ARN" \
  --handler handler.lambda_handler \
  --zip-file fileb://$ZIP_FILE \
  --region $REGION

echo "Lambda function deployed: $FUNCTION_NAME"

# ─────────────────────────────────────────────
# Step 4: Schedule Lambda with EventBridge Rule
# ─────────────────────────────────────────────
echo "Creating daily EventBridge rule..."

aws events put-rule \
  --name $RULE_NAME \
  --schedule-expression "rate(1 day)" \
  --region $REGION

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id event-invoke-rule \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:$REGION:$ACCOUNT_ID:rule/$RULE_NAME" \
  --region $REGION

aws events put-targets \
  --rule $RULE_NAME \
  --targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME" \
  --region $REGION

# ─────────────────────────────────────────────
# Step 5: Confirm
# ─────────────────────────────────────────────
echo "Lambda function scheduled daily!"