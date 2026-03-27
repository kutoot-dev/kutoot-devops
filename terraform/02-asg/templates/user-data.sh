#!/bin/bash
# Kutoot Laravel - Auto setup on instance boot (Launch Template User Data)
# Runs at first boot when ASG scales. Instance is fully deployed and ready for traffic.

set -e
exec > >(tee /var/log/kutoot-userdata.log) 2>&1

# On failure, write status so we can debug (curl /userdata-status.txt)
trap 'mkdir -p /var/www/kutoot/public; echo "userdata-failed" > /var/www/kutoot/public/userdata-status.txt 2>/dev/null || true' ERR

DB_HOST="${db_host}"
DB_DATABASE="${db_database}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
LARAVEL_REPO="${laravel_repo_url}"
ENV_S3_URI="${env_s3_uri}"
CODE_S3_URI="${code_s3_uri}"

echo "=== Kutoot User Data - $(date) ==="

export HOME=/root
export COMPOSER_HOME=/root/.composer

# Wait for apt lock
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done

echo ">>> Installing PHP 8.4, Node.js 20, Nginx, Composer..."
export DEBIAN_FRONTEND=noninteractive
add-apt-repository ppa:ondrej/php -y 2>/dev/null || true
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get update -qq
apt-get install -y nginx php8.4-fpm php8.4-cli php8.4-mysql php8.4-mbstring php8.4-xml php8.4-curl \
  php8.4-zip php8.4-gd php8.4-bcmath php8.4-intl php8.4-opcache unzip git awscli supervisor python3

# Ensure npm is in PATH (NodeSource install may not update current shell)
export PATH="/usr/bin:/usr/local/bin:$PATH"

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
update-alternatives --set php /usr/bin/php8.4 2>/dev/null || true

echo ">>> Fetching Laravel code..."
mkdir -p /tmp/kutoot-deploy
cd /tmp/kutoot-deploy

# Try S3 first (reliable, no GitHub needed) - run deploy workflow to update
if [ -n "$CODE_S3_URI" ]; then
  if aws s3 cp "$CODE_S3_URI" kutoot.tar.gz; then
    echo "    OK: Code from S3, extracting..."
    tar -xzf kutoot.tar.gz
    [ -d kutoot ] && mv kutoot laravel
  else
    echo "    WARN: S3 fetch failed (check IAM, bucket), trying Git..."
  fi
fi
if [ ! -d laravel ] || [ ! -f laravel/artisan ]; then
  if [ -n "$LARAVEL_REPO" ]; then
    echo "    Cloning from Git..."
    git clone --branch main --depth 1 "$LARAVEL_REPO" laravel 2>/dev/null || {
      echo "ERROR: Git clone failed (private repo? add token to laravel_repo_url)"
      exit 1
    }
  else
    echo "ERROR: No Laravel code. S3 failed and no laravel_repo_url configured."
    exit 1
  fi
fi

[ ! -f laravel/artisan ] && { echo "ERROR: Laravel code incomplete (no artisan)"; exit 1; }

echo ">>> Setting up Nginx (with @laravel fallback + buffer fix)..."
mkdir -p /var/www/kutoot/public
echo "OK" > /var/www/kutoot/public/index.html

# Increase worker_connections for load (default 768 not enough for 2000+ concurrent)
sed -i 's/worker_connections [0-9]*/worker_connections 8192/' /etc/nginx/nginx.conf 2>/dev/null || true

cat > /etc/nginx/sites-available/kutoot-backend << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/kutoot/public;
    index index.php index.html;
    server_name _;

    client_max_body_size 1024M;
    client_header_buffer_size 16k;
    large_client_header_buffers 4 32k;

    location / {
        try_files $uri $uri/ @laravel;
    }

    location @laravel {
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param REQUEST_URI $request_uri;
        include fastcgi_params;
        fastcgi_read_timeout 120;

        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 120;

        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/kutoot-backend /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t

echo ">>> Copying Laravel files..."
cp -r /tmp/kutoot-deploy/laravel/. /var/www/kutoot/
cd /var/www/kutoot
rm -rf /tmp/kutoot-deploy

echo ">>> Configuring .env..."
if [ -n "$ENV_S3_URI" ]; then
  if aws s3 cp "$ENV_S3_URI" .env 2>/dev/null; then
    echo "    OK: .env from S3"
    sed -i 's/\r$//' .env
  else
    echo "    WARN: S3 .env failed, using .env.example"
    cp .env.example .env
  fi
else
  cp .env.example .env
fi
[ -f .env ] && sed -i 's/\r$//' .env

# S3 is source of truth for DB_PASSWORD when tf var db_password is empty.
# In kutoot.env use double quotes if the password contains #, !, spaces, etc.:
#   DB_PASSWORD="your#secret"
sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
if [ -n "$DB_PASSWORD" ]; then
  export _KUTOOT_UD_DB_PASSWORD="$DB_PASSWORD"
  python3 <<'PY'
import os

path = ".env"
pwd = os.environ["_KUTOOT_UD_DB_PASSWORD"]
esc = pwd.replace("\\", "\\\\").replace('"', '\\"')
replacement = f'DB_PASSWORD="{esc}"\n'

lines = []
found = False
with open(path, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        if line.startswith("DB_PASSWORD="):
            lines.append(replacement)
            found = True
        else:
            lines.append(line)
if not found:
    lines.append(replacement)
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.writelines(lines)
PY
  unset _KUTOOT_UD_DB_PASSWORD
fi
sed -i 's/APP_DEBUG=.*/APP_DEBUG=false/' .env
sed -i 's/APP_ENV=.*/APP_ENV=production/' .env
sed -i 's|APP_URL=.*|APP_URL=https://dev.kutoot.com|' .env

echo ">>> Running composer install..."
export HOME=$${HOME:-/root}
export COMPOSER_HOME=$${COMPOSER_HOME:-/root/.composer}
composer install --optimize-autoloader --no-dev --no-interaction

echo ">>> Building frontend assets..."
if [ -f public/build/manifest.json ]; then
  echo "    OK: Using pre-built assets from tarball"
else
  export PATH="/usr/bin:/usr/local/bin:$PATH"
  npm ci
  npm run build
fi

echo ">>> Generating keys..."
php artisan key:generate --force
php artisan jwt:secret --force 2>/dev/null || true

echo ">>> Running migrations..."
php artisan migrate --force 2>/dev/null || true

echo ">>> Optimize (clear + cache)..."
php artisan optimize:clear
php artisan optimize
php artisan storage:link

echo ">>> Setting up Laravel Scheduler (crontab)..."
(crontab -l 2>/dev/null | grep -v "artisan schedule:run" ; echo "* * * * * cd /var/www/kutoot && php artisan schedule:run >> /dev/null 2>&1") | crontab -

echo ">>> Setting up Supervisor (queue:work)..."
systemctl enable supervisor
systemctl start supervisor
cat > /etc/supervisor/conf.d/kutoot-worker.conf << 'SUPERVISOR'
[program:kutoot-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/kutoot/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/kutoot/storage/logs/worker.log
stopwaitsecs=3600
SUPERVISOR
supervisorctl reread
supervisorctl update
supervisorctl start kutoot-worker:*

echo ">>> Setting permissions..."
chown -R www-data:www-data /var/www/kutoot
chmod -R 775 /var/www/kutoot/storage
chmod -R 775 /var/www/kutoot/bootstrap/cache

# www-data HOME is often /var/www; PsySH/tinker need ~/.config writable
mkdir -p /var/www/.config/psysh
chown -R www-data:www-data /var/www/.config

systemctl restart php8.4-fpm nginx

echo "userdata-complete" > /var/www/kutoot/public/userdata-status.txt
echo "=== Kutoot User Data Complete - $(date) ==="
