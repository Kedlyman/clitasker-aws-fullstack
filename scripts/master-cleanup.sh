#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Welcome Message
# ─────────────────────────────────────────────
echo ""
echo "WARNING: This script will DESTROY all AWS resources created by CLITasker."
echo "This includes your VPC, EC2 instance, RDS DB, S3 bucket, IAM roles, Lambda, and CloudWatch alarms."
echo ""
read -rp "Are you sure you want to proceed? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# ─────────────────────────────────────────────
# Function Helpers
# ─────────────────────────────────────────────
run_cleanup_step() {
    echo ""
    echo "Running: $1"
    bash "$1"
    echo "Done: $1"
    sleep 2
}

# ─────────────────────────────────────────────
# Execute Cleanup
# ─────────────────────────────────────────────
run_cleanup_step "10-cleanup.sh"

# ─────────────────────────────────────────────
# Completion Message
# ─────────────────────────────────────────────
echo ""
echo "Cleanup Complete!"
echo "----------------------------------------------------------"
echo "All resources from the CLITasker project have been deleted."
echo "Check the AWS Console to confirm deletion."
echo ""