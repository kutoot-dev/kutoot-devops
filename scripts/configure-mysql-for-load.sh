#!/bin/bash
# Configure MySQL for high connection load (2000+ concurrent users)
# Run on MySQL EC2: scp this file, then: sudo bash configure-mysql-for-load.sh
#
# Usage: sudo bash configure-mysql-for-load.sh [max_connections]
# Default: 5000 (for 2000 concurrent users)
# For 1 lakh: 100000 (needs 16GB+ RAM, OS tuning)

set -e

MAX_CONN="${1:-5000}"
CONF_DIR="/etc/mysql/mysql.conf.d"
CONF_FILE="$CONF_DIR/99-load-tuning.cnf"

echo "=== MySQL Load Tuning (max_connections=$MAX_CONN) ==="

[ -d "$CONF_DIR" ] || { echo "ERROR: $CONF_DIR not found. Is MySQL installed?"; exit 1; }

echo ">>> Creating $CONF_FILE"
sudo tee "$CONF_FILE" > /dev/null << EOF
# High connection load - added by configure-mysql-for-load.sh
[mysqld]
max_connections = $MAX_CONN
wait_timeout = 300
interactive_timeout = 300
thread_cache_size = 128
EOF

echo ">>> Restarting MySQL..."
sudo systemctl restart mysql

echo ">>> Verifying..."
mysql -e "SHOW VARIABLES LIKE 'max_connections';"

echo ""
echo "=== Done. max_connections = $MAX_CONN ==="
echo "For 1 lakh (100k): sudo bash $0 100000 (needs 16GB+ RAM)"
