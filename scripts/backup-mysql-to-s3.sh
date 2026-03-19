#!/bin/bash
# MySQL backup to S3 - Run on MySQL EC2 (cron daily)
# Requires: IAM role with S3 PutObject, AWS CLI
# Uses ~/.my.cnf for credentials (chmod 600)
set -e
export HOME="${HOME:-/home/ubuntu}"
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

S3_BUCKET="${1:-kutoot-mysql-backups}"
DB_NAME="${2:-kutoot_backend}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo ">>> Backing up $DB_NAME to S3..."
DB_USER=$(grep '^user=' "$HOME/.my.cnf" 2>/dev/null | cut -d= -f2)
DB_PASS=$(grep '^password=' "$HOME/.my.cnf" 2>/dev/null | cut -d= -f2)
mysqldump -h 127.0.0.1 -u "${DB_USER:-admin}" -p"${DB_PASS}" \
  --single-transaction --skip-lock-tables --set-gtid-purged=OFF \
  --no-tablespaces --routines --triggers --events \
  "$DB_NAME" | gzip > "$BACKUP_FILE"

aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/daily/${DB_NAME}_${TIMESTAMP}.sql.gz"
rm -f "$BACKUP_FILE"

echo ">>> Backup complete: s3://${S3_BUCKET}/daily/${DB_NAME}_${TIMESTAMP}.sql.gz"
