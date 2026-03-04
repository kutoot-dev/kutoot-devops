#!/bin/bash
# Backup MySQL databases from RDS or EC2
# Usage: ./backup-mysql.sh <HOST> <USER> <OUTPUT_DIR>

set -e

HOST=${1:-"127.0.0.1"}
USER=${2:-"admin"}
OUTPUT_DIR=${3:-"./backups"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "Backing up databases from $HOST..."

for DB in kutoot kutoot1 kutoot_backend; do
  echo "Backing up $DB..."
  mysqldump -h "$HOST" -u "$USER" -p \
    --single-transaction --skip-lock-tables --set-gtid-purged=OFF \
    --routines --triggers --events \
    "$DB" > "$OUTPUT_DIR/${DB}_${TIMESTAMP}.sql"
done

echo "Backup complete: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.sql
