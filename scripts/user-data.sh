#!/bin/bash
set -euxo pipefail

# ─────────────────────────────────────────────
# System Preparation
# ─────────────────────────────────────────────
apt-get update -y
apt-get install -y python3 python3-pip git unzip awscli jq

# ─────────────────────────────────────────────
# Install Python Dependencies
# ─────────────────────────────────────────────
pip3 install flask psycopg2-binary boto3

# ─────────────────────────────────────────────
# Clone Your Flask App from GitHub
# ─────────────────────────────────────────────
cd /home/ubuntu
git clone https://github.com/Kedlyman/aws-cli-project-flask.git app
cd app

# ─────────────────────────────────────────────
# Fetch Secrets from AWS Secrets Manager
# ─────────────────────────────────────────────
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id aws-cli-project-db-password \
  --query SecretString \
  --output text \
  --region eu-central-1)

export DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
export DB_PASS=$(echo "$SECRET_JSON" | jq -r .password)

# ─────────────────────────────────────────────
# Fetch RDS Endpoint
# ─────────────────────────────────────────────
export DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier aws-cli-project-db \
  --query "DBInstances[0].Endpoint.Address" \
  --output text \
  --region eu-central-1)

export DB_NAME="postgres"

# ─────────────────────────────────────────────
# Fetch S3 Bucket Name 
# ─────────────────────────────────────────────
export S3_BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, 'aws-cli-project-bucket')].Name | [0]" \
  --output text)

# ─────────────────────────────────────────────
# Run the Flask App
# ─────────────────────────────────────────────
export FLASK_APP=app.py
export FLASK_RUN_PORT=80
flask run --host=0.0.0.0