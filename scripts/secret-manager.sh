aws secretsmanager create-secret \
  --name aws-cli-project-db-password \
  --description "Password for RDS PostgreSQL DB" \
  --secret-string '{"username":"dbmaster","password":"aV9#rT2!xLm_8QzD"}' \
  --region eu-central-1