#!/bin/bash

trap 'echo "Cleanup script failed unexpectedly. Check the step logs above." >&2' ERR
set -euo pipefail

REGION="eu-central-1"
echo ""
echo "Starting Cleanup of All CLITasker AWS Resources..."
echo "------------------------------------------------------"

# ─────────────────────────────────────────────
# Step 1: Detach IAM role from EC2
# ─────────────────────────────────────────────
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aws-cli-project-ec2" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region $REGION || echo "")

if [[ -n "$INSTANCE_ID" ]]; then
  echo "Detaching IAM instance profile from EC2..."
  ASSOC_ID=$(aws ec2 describe-iam-instance-profile-associations \
    --query "IamInstanceProfileAssociations[?InstanceId=='$INSTANCE_ID'].AssociationId" \
    --output text \
    --region $REGION || echo "")
  if [[ -n "$ASSOC_ID" ]]; then
    aws ec2 disassociate-iam-instance-profile \
      --association-id "$ASSOC_ID" \
      --region $REGION || true
  fi
fi

# ─────────────────────────────────────────────
# Step 2: Delete Lambda + EventBridge rule
# ─────────────────────────────────────────────
echo "Deleting Lambda function and its trigger..."
aws events remove-targets --rule daily-task-digest-rule --ids 1 --region $REGION || true
aws events delete-rule --name daily-task-digest-rule --region $REGION || true
aws lambda delete-function --function-name aws-cli-project-daily-summary --region $REGION || true

# ─────────────────────────────────────────────
# Step 3: Delete CloudWatch Alarms
# ─────────────────────────────────────────────
echo "Deleting CloudWatch alarms..."
aws cloudwatch delete-alarms --alarm-names \
  aws-cli-project-High-CPU \
  CLITasker-Unhealthy-Hosts \
  --region $REGION || true

# ─────────────────────────────────────────────
# Step 4: Terminate EC2 Instance
# ─────────────────────────────────────────────
if [[ -n "$INSTANCE_ID" ]]; then
  echo "Terminating EC2 instance: $INSTANCE_ID"
  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION || true
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION || true
fi

# ─────────────────────────────────────────────
# Step 5: Delete Load Balancer and Target Group
# ─────────────────────────────────────────────
echo "Deleting ALB and Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups \
  --names aws-cli-project-target-group \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --region $REGION || echo "")

LB_ARN=$(aws elbv2 describe-load-balancers \
  --names aws-cli-project-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text \
  --region $REGION || echo "")

if [[ -n "$LB_ARN" ]]; then
  LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $LB_ARN \
    --query 'Listeners[0].ListenerArn' \
    --output text \
    --region $REGION || echo "")
  if [[ -n "$LISTENER_ARN" ]]; then
    aws elbv2 delete-listener --listener-arn $LISTENER_ARN --region $REGION || true
  fi
  aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN --region $REGION || true
  aws elbv2 wait load-balancers-deleted --load-balancer-arns $LB_ARN --region $REGION || true
fi

if [[ -n "$TG_ARN" ]]; then
  aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION || true
fi

# ─────────────────────────────────────────────
# Step 6: Delete RDS Instance
# ─────────────────────────────────────────────
echo "Deleting RDS DB instance..."
aws rds delete-db-instance \
  --db-instance-identifier aws-cli-project-db \
  --skip-final-snapshot \
  --region $REGION || true

aws rds wait db-instance-deleted \
  --db-instance-identifier aws-cli-project-db \
  --region $REGION || true

# ─────────────────────────────────────────────
# Step 7: Delete DB Subnet Group
# ─────────────────────────────────────────────
aws rds delete-db-subnet-group \
  --db-subnet-group-name aws-cli-project-db-subnet-group \
  --region $REGION || true

# ─────────────────────────────────────────────
# Step 8: Delete IAM Roles, Policies, Instance Profiles
# ─────────────────────────────────────────────
echo "Deleting IAM roles and instance profiles..."

for ROLE in aws-cli-project-ec2-role aws-cli-project-lambda-role; do
  POLICIES=$(aws iam list-attached-role-policies \
    --role-name $ROLE \
    --query 'AttachedPolicies[*].PolicyArn' \
    --output text \
    --region $REGION || echo "")
  for POLICY_ARN in $POLICIES; do
    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY_ARN --region $REGION || true
  done

  INLINE_POLICIES=$(aws iam list-role-policies --role-name $ROLE --region $REGION --output text || echo "")
  for INLINE_POLICY in $INLINE_POLICIES; do
    aws iam delete-role-policy --role-name $ROLE --policy-name $INLINE_POLICY --region $REGION || true
  done
done

aws iam remove-role-from-instance-profile \
  --instance-profile-name aws-cli-project-ec2-role \
  --role-name aws-cli-project-ec2-role \
  --region $REGION || true

sleep 5

aws iam delete-instance-profile \
  --instance-profile-name aws-cli-project-ec2-role \
  --region $REGION || true

aws iam delete-role --role-name aws-cli-project-ec2-role --region $REGION || true
aws iam delete-role --role-name aws-cli-project-lambda-role --region $REGION || true

# ─────────────────────────────────────────────
# Step 9: Delete S3 Bucket and contents
# ─────────────────────────────────────────────
echo "Emptying and deleting S3 bucket..."
S3_BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name, 'aws-cli-project-bucket')].Name | [0]" \
  --output text)

if [[ "$S3_BUCKET" != "None" ]]; then
  aws s3 rm s3://$S3_BUCKET --recursive || true
  aws s3api delete-bucket --bucket $S3_BUCKET --region $REGION || true
fi

# ─────────────────────────────────────────────
# Step 10: Delete Secrets
# ─────────────────────────────────────────────
echo "Deleting secret..."
aws secretsmanager delete-secret \
  --secret-id aws-cli-project-db-password \
  --force-delete-without-recovery \
  --region $REGION || true

# ─────────────────────────────────────────────
# Step 11: Delete Security Groups
# ─────────────────────────────────────────────
echo "Deleting security groups..."
for name in aws-cli-project-EC2-SG aws-cli-project-RDS-SG aws-cli-project-ALB-SG; do
  SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=$name" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region $REGION || echo "")
  if [[ -n "$SG_ID" && "$SG_ID" != "None" ]]; then
    aws ec2 delete-security-group --group-id $SG_ID --region $REGION || true
  fi
done

# ─────────────────────────────────────────────
# Step 12: Delete VPC & Dependencies
# ─────────────────────────────────────────────
echo "Deleting VPC and attached resources..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=aws-cli-project-VPC" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION || echo "")

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then

  # Delete ENIs
  ENI_IDS=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "NetworkInterfaces[*].NetworkInterfaceId" \
    --output text \
    --region $REGION || echo "")
  for ENI_ID in $ENI_IDS; do
    aws ec2 delete-network-interface --network-interface-id $ENI_ID --region $REGION || true
  done

  # IGW
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text \
    --region $REGION || echo "")
  if [[ -n "$IGW_ID" ]]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION || true
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION || true
  fi

  # Subnets
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[*].SubnetId" \
    --output text \
    --region $REGION)
  for SUBNET_ID in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION || true
  done

  # Route Tables
  RT_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "RouteTables[*].RouteTableId" \
    --output text \
    --region $REGION)
  for RT_ID in $RT_IDS; do
    ASSOC_IDS=$(aws ec2 describe-route-tables \
      --route-table-ids $RT_ID \
      --query "RouteTables[0].Associations[?Main==\`false\`].RouteTableAssociationId" \
      --output text \
      --region $REGION || echo "")
    for ASSOC_ID in $ASSOC_IDS; do
      aws ec2 disassociate-route-table --association-id $ASSOC_ID --region $REGION || true
    done
    MAIN=$(aws ec2 describe-route-tables \
      --route-table-ids $RT_ID \
      --query "RouteTables[0].Associations[0].Main" \
      --output text \
      --region $REGION || echo "false")
    if [[ "$MAIN" != "true" ]]; then
      aws ec2 delete-route-table --route-table-id $RT_ID --region $REGION || true
    fi
  done

  aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION || true
fi

# ─────────────────────────────────────────────
# Step 13: Delete CloudWatch log groups
# ─────────────────────────────────────────────
echo "Deleting CloudWatch log groups..."
LOG_GROUPS=$(aws logs describe-log-groups \
  --query "logGroups[?starts_with(logGroupName, '/aws/lambda/aws-cli-project-daily-summary')].logGroupName" \
  --output text \
  --region $REGION || echo "")

for LOG in $LOG_GROUPS; do
  aws logs delete-log-group --log-group-name "$LOG" --region $REGION || true
done

echo ""
echo "All CLITasker project resources cleaned up successfully."