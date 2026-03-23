#!/bin/bash
# MySQL EC2 - Install MySQL and create database
set -e
exec > >(tee /var/log/mysql-userdata.log) 2>&1

DB_DATABASE="${db_database}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"

echo "=== MySQL User Data - $(date) ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y mysql-server

systemctl start mysql
systemctl enable mysql

# Create database and user
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_DATABASE\`;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_DATABASE\`.* TO '$DB_USERNAME'@'%';"
mysql -e "FLUSH PRIVILEGES;"

# Allow remote connections (Ubuntu 22.04 MySQL 8)
if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]; then
  sed -i 's/^bind-address\s*=\s*.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
fi

# High connection load (2000+ concurrent users / 1 lakh requests)
cat > /etc/mysql/mysql.conf.d/99-load-tuning.cnf << 'MYSQL'
[mysqld]
max_connections = 5000
wait_timeout = 300
interactive_timeout = 300
thread_cache_size = 128
MYSQL

systemctl restart mysql

echo "=== MySQL User Data Complete - $(date) ==="
