# MySQL Configuration for High Load

Configure MySQL to handle 2000+ concurrent users (load test / 1 lakh requests).

---

## Quick Apply (on MySQL EC2 instance)

```bash
# 1. Copy script to MySQL server
scp -i kutoot-sql.pem kutoot-devops/scripts/configure-mysql-for-load.sh ubuntu@<MYSQL_IP>:~/

# 2. SSH and run
ssh -i kutoot-sql.pem ubuntu@<MYSQL_IP>
sudo bash configure-mysql-for-load.sh

# Default: 5000 connections (for 2000 concurrent users)
# For 1 lakh: sudo bash configure-mysql-for-load.sh 100000
```

# Manual Config

```bash
# Or manually:
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# Add under [mysqld]:
# max_connections = 5000
# wait_timeout = 300
# interactive_timeout = 300
# thread_cache_size = 128

sudo systemctl restart mysql
mysql -e "SHOW VARIABLES LIKE 'max_connections';"
```

---

## Recommended Settings (2000 concurrent users)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| max_connections | 5000 | ~2.5x concurrent users (each request uses 1 connection) |
| wait_timeout | 300 | Close idle connections after 5 min |
| interactive_timeout | 300 | Same for interactive sessions |
| thread_cache_size | 128 | Reuse threads, faster new connections |

**Memory:** 5000 connections × ~256KB ≈ 1.25GB. MySQL instance should have **4GB+ RAM**.

---

## For 1 Lakh (100,000) Connections

⚠️ **Requires significant resources:**
- **RAM:** ~25GB+ for connections alone (100k × 256KB)
- **Instance:** Use large RDS/EC2 (e.g. r5.2xlarge or bigger)
- **OS Tuning:** `ulimit -n 100000`, systemd `LimitNOFILE=1000000`
- **MySQL Thread Pool:** Consider thread pool plugin for efficiency

**To set 10000 connections** (step toward 100k):
```bash
sudo bash scripts/configure-mysql-for-load.sh 10000
```

---

## Verify After Restart

```bash
mysql -e "SHOW VARIABLES LIKE 'max_connections';"
mysql -e "SHOW STATUS LIKE 'Threads_connected';"   # Current connections
mysql -e "SHOW STATUS LIKE 'Max_used_connections';" # Peak ever used
```
