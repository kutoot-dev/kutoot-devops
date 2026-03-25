#!/bin/bash
# MySQL EC2 — bind to private IP only; app user scoped to db_database
set -e
exec > >(tee /var/log/mysql-userdata.log) 2>&1

DB_DATABASE="${db_database}"
DB_USERNAME="${db_username}"
DB_USER_HOST="${db_user_host}"
DB_PASSWORD=$$(echo "${db_password_b64}" | base64 -d)

echo "=== MySQL User Data - $$(date) ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y mysql-server

systemctl start mysql
systemctl enable mysql

TOKEN=$$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$$(curl -s -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
if [ -z "$$PRIVATE_IP" ]; then
  echo "ERROR: could not read local-ipv4 from IMDS"
  exit 1
fi

PASS_ESC="$${DB_PASSWORD//\'/\'\'}"

mysql -e "CREATE DATABASE IF NOT EXISTS \`$$DB_DATABASE\`;"
mysql -e "CREATE USER IF NOT EXISTS '$$DB_USERNAME'@'$$DB_USER_HOST' IDENTIFIED BY '$$PASS_ESC';"
mysql -e "ALTER USER '$$DB_USERNAME'@'$$DB_USER_HOST' IDENTIFIED BY '$$PASS_ESC';"
mysql -e "GRANT ALL PRIVILEGES ON \`$$DB_DATABASE\`.* TO '$$DB_USERNAME'@'$$DB_USER_HOST';"
mysql -e "FLUSH PRIVILEGES;"

if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]; then
  sed -i "s/^bind-address\s*=.*/bind-address = $$PRIVATE_IP/" /etc/mysql/mysql.conf.d/mysqld.cnf
fi

cat > /etc/mysql/mysql.conf.d/99-load-tuning.cnf << 'MYSQL'
[mysqld]
max_connections = 5000
wait_timeout = 300
interactive_timeout = 300
thread_cache_size = 128
MYSQL

systemctl restart mysql

echo "=== MySQL User Data Complete - bind $$PRIVATE_IP - $$(date) ==="
