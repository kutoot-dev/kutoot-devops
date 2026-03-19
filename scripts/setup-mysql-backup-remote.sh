#!/bin/bash
# Run on MySQL EC2 - setup backup cron. Called by setup-mysql-backup.ps1
set -e
DB_USER="$1"
DB_PASS="$2"
S3_BUCKET="${3:-kutoot-mysql-backups}"
DB_NAME="${4:-kutoot_backend}"

if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
  echo "Usage: $0 <DB_USER> <DB_PASS> [S3_BUCKET] [DB_NAME]"
  exit 1
fi

# Fix line endings on backup script
sed -i 's/\r$//' ~/backup-mysql-to-s3.sh 2>/dev/null || true
chmod +x ~/backup-mysql-to-s3.sh

# Install AWS CLI v2
if ! command -v aws &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y unzip curl
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  cd /tmp && unzip -o -q awscliv2.zip && sudo ./aws/install && rm -rf aws awscliv2.zip
fi

# Create .my.cnf
cat > ~/.my.cnf << EOF
[client]
user=$DB_USER
password=$DB_PASS
EOF
chmod 600 ~/.my.cnf

# Add cron
touch /tmp/cron.new
crontab -l 2>/dev/null | grep -v backup-mysql-to-s3 >> /tmp/cron.new || true
echo "0 2 * * * ~/backup-mysql-to-s3.sh $S3_BUCKET $DB_NAME >> /var/log/mysql-backup.log 2>&1" >> /tmp/cron.new
crontab /tmp/cron.new
rm -f /tmp/cron.new

echo "Backup cron installed. Runs daily at 2 AM UTC."
crontab -l
