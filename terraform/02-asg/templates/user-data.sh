#!/bin/bash
# Kutoot Laravel - Auto setup on instance boot (Launch Template User Data)
# Runs at first boot to deploy Laravel at /var/www/kutoot

set -e
exec > >(tee /var/log/kutoot-userdata.log) 2>&1

DB_HOST="${db_host}"
DB_DATABASE="${db_database}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
LARAVEL_REPO="${laravel_repo_url}"

echo "=== Kutoot User Data - $(date) ==="

# Wait for apt lock
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done

echo ">>> Installing PHP 8.4, Nginx, Composer..."
export DEBIAN_FRONTEND=noninteractive
add-apt-repository ppa:ondrej/php -y 2>/dev/null || true
apt-get update -qq
apt-get install -y nginx php8.4-fpm php8.4-cli php8.4-mysql php8.4-mbstring php8.4-xml php8.4-curl \
  php8.4-zip php8.4-gd php8.4-bcmath php8.4-intl php8.4-opcache unzip git

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
update-alternatives --set php /usr/bin/php8.4 2>/dev/null || true

echo ">>> Cloning Laravel..."
mkdir -p /tmp/kutoot-deploy
cd /tmp/kutoot-deploy
git clone --branch main --depth 1 "$LARAVEL_REPO" laravel 2>/dev/null || {
  echo "ERROR: Git clone failed. Check LARAVEL_REPO and network."
  exit 1
}

echo ">>> Setting up Nginx..."
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
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 120;
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
cp .env.example .env
sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env
sed -i 's/APP_DEBUG=.*/APP_DEBUG=false/' .env
sed -i 's/APP_ENV=.*/APP_ENV=production/' .env

echo ">>> Running composer install..."
composer install --optimize-autoloader --no-dev --no-interaction

echo ">>> Generating keys..."
php artisan key:generate --force
php artisan jwt:secret --force

echo ">>> Caching config..."
php artisan config:cache
php artisan storage:link

echo ">>> Setting permissions..."
chown -R www-data:www-data /var/www/kutoot
chmod -R 775 /var/www/kutoot/storage
chmod -R 775 /var/www/kutoot/bootstrap/cache

systemctl restart php8.4-fpm nginx

echo "=== Kutoot User Data Complete - $(date) ==="
