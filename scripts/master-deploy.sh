#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
echo ""
echo "Starting Full Deployment for CLITasker AWS CLI Project"
echo "----------------------------------------------------------"
PROJECT_ROOT=$(pwd)
REGION="eu-central-1"

# ─────────────────────────────────────────────
# Function Helpers
# ─────────────────────────────────────────────
run_step() {
    echo ""
    echo "Running: $1"
    bash "$1"
    echo "Done: $1"
    sleep 2
}

# ─────────────────────────────────────────────
# Step-by-step Deployment
# ─────────────────────────────────────────────
run_step "01-create-vpc.sh"
run_step "02-create-security-groups.sh"
run_step "secret-manager.sh"
run_step "03-create-rds.sh"
run_step "04-create-s3.sh"
run_step "05-create-iam-roles.sh"
run_step "06-launch-ec2.sh"
run_step "07-setup-elb.sh"
run_step "08-create-lambda.sh"
run_step "09-cloudwatch-alarms.sh"

# ─────────────────────────────────────────────
# Completion Message
# ─────────────────────────────────────────────
echo ""
echo "Deployment Complete!"
echo "----------------------------------------------------------"
echo "To access the app:"
echo "aws elbv2 describe-load-balancers --names aws-cli-project-alb --region $REGION --query 'LoadBalancers[0].DNSName' --output text"