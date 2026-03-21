#!/bin/bash
# Kutoot Laravel - Auto setup on instance boot (Launch Template User Data)
# Runs at first boot when ASG scales. Instance is fully deployed and ready for traffic.

set -e
exec > >(tee /var/log/kutoot-userdata.log) 2>&1

DB_HOST="${db_host}"
DB_DATABASE="${db_database}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
LARAVEL_REPO="${laravel_repo_url}"
ENV_S3_URI="${env_s3_uri}"
CODE_S3_URI="${code_s3_uri}"

echo "=== Kutoot User Data - $(date) ==="

# Wait for apt lock
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done

echo ">>> Installing PHP 8.4, Node.js 20, Nginx, Composer..."
export DEBIAN_FRONTEND=noninteractive
add-apt-repository ppa:ondrej/php -y 2>/dev/null || true
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get update -qq
apt-get install -y nginx php8.4-fpm php8.4-cli php8.4-mysql php8.4-mbstring php8.4-xml php8.4-curl \
  php8.4-zip php8.4-gd php8.4-bcmath php8.4-intl php8.4-opcache unzip git awscli

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
update-alternatives --set php /usr/bin/php8.4 2>/dev/null || true

echo ">>> Fetching Laravel code..."
mkdir -p /tmp/kutoot-deploy
cd /tmp/kutoot-deploy

# Try S3 first (reliable, no GitHub needed) - run upload-kutoot-to-s3.ps1 to update
if [ -n "$CODE_S3_URI" ] && aws s3 cp "$CODE_S3_URI" kutoot.tar.gz 2>/dev/null; then
  echo "    OK: Code from S3, extracting..."
  tar -xzf kutoot.tar.gz
  [ -d kutoot ] && mv kutoot laravel
else
  echo "    S3 not found, cloning from Git..."
  git clone --branch main --depth 1 "$LARAVEL_REPO" laravel 2>/dev/null || {
    echo "ERROR: Neither S3 code nor Git clone worked. Run upload-kutoot-to-s3.ps1 first."
    exit 1
  }
fi

[ ! -f laravel/artisan ] && { echo "ERROR: Laravel code incomplete (no artisan)"; exit 1; }

echo ">>> Setting up Nginx (with @laravel fallback + buffer fix)..."
mkdir -p /var/www/kutoot/public
echo "OK" > /var/www/kutoot/public/index.html

cat > /etc/nginx/sites-available/kutoot-backend << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/kutoot/public;
    index index.php index.html;
    server_name _;

    client_max_body_size 1024M;

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
    echo "    OK: .env from S3 ($ENV_S3_URI)"
  else
    echo "    WARN: S3 .env failed, using .env.example"
    cp .env.example .env
  fi
else
  cp .env.example .env
fi

sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env
sed -i 's/APP_DEBUG=.*/APP_DEBUG=false/' .env
sed -i 's/APP_ENV=.*/APP_ENV=production/' .env
sed -i 's|APP_URL=.*|APP_URL=https://dev.kutoot.com|' .env

echo ">>> Running composer install..."
composer install --optimize-autoloader --no-dev --no-interaction

echo ">>> Building frontend assets..."
npm ci
npm run build

echo ">>> Generating keys..."
php artisan key:generate --force
php artisan jwt:secret --force 2>/dev/null || true

echo ">>> Running migrations..."
php artisan migrate --force 2>/dev/null || true

echo ">>> Caching config..."
php artisan config:cache
php artisan storage:link

echo ">>> Setting permissions..."
chown -R www-data:www-data /var/www/kutoot
chmod -R 775 /var/www/kutoot/storage
chmod -R 775 /var/www/kutoot/bootstrap/cache

systemctl restart php8.4-fpm nginx

echo "=== Kutoot User Data Complete - $(date) ==="
