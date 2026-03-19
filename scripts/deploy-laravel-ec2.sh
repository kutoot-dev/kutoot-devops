#!/bin/bash
# Kutoot Laravel Deployment Script - Run on EC2 after SSH login
# Prerequisite: Run scp from Windows first to copy Laravel files to /home/ubuntu/

set -e

# ============ CONFIGURE THESE ============
DB_HOST="172.31.45.181"
DB_DATABASE="kutoot_backend"
DB_USERNAME="admin"
# Set password: replace CHANGE_ME or run: ./deploy-laravel-ec2.sh your_password
DB_PASSWORD="${1:-CHANGE_ME}"
# =========================================

echo "=== Kutoot Laravel Deployment ==="

# Resolve Laravel source (SCP creates /home/ubuntu/kutoot/ when copying folder)
LARAVEL_SRC="/home/ubuntu"
[ -f /home/ubuntu/kutoot/artisan ] && LARAVEL_SRC="/home/ubuntu/kutoot"
[ -f /home/ubuntu/artisan ] && LARAVEL_SRC="/home/ubuntu"

if [ ! -f "$LARAVEL_SRC/artisan" ]; then
    echo ">>> Laravel files not found. Cloning from Git..."
    echo "    git@github.com:kutoot-dev/kutoot.git (branch: main)"
    sudo mkdir -p /home/ubuntu
    sudo git clone --branch main git@github.com:kutoot-dev/kutoot.git /home/ubuntu/kutoot 2>/dev/null || {
        echo "ERROR: Git clone failed. Ensure SSH key is set up for github.com."
        echo "Alternative: scp -i kutoot-sql.pem -r kutoot/* ubuntu@<IP>:/home/ubuntu/"
        exit 1
    }
    sudo cp -r /home/ubuntu/kutoot/. /home/ubuntu/
    sudo rm -rf /home/ubuntu/kutoot
fi

echo ">>> Installing PHP 8.4, Node.js 20, Nginx, Composer..."
sudo add-apt-repository ppa:ondrej/php -y 2>/dev/null || true
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt update -qq
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  nginx nodejs \
  php8.4-fpm php8.4-cli php8.4-mysql php8.4-mbstring php8.4-xml php8.4-curl \
  php8.4-zip php8.4-gd php8.4-bcmath php8.4-intl php8.4-opcache \
  unzip git

echo ">>> Installing Composer..."
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo update-alternatives --set php /usr/bin/php8.4 2>/dev/null || true

echo ">>> Setting up Nginx..."
sudo mkdir -p /var/www/kutoot/public
echo "OK" | sudo tee /var/www/kutoot/public/index.html > /dev/null

sudo tee /etc/nginx/sites-available/kutoot-backend > /dev/null << 'NGINX'
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

sudo ln -sf /etc/nginx/sites-available/kutoot-backend /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart php8.4-fpm nginx

echo ">>> Copying Laravel files..."
sudo cp -r "$LARAVEL_SRC"/. /var/www/kutoot/
sudo chown -R ubuntu:ubuntu /var/www/kutoot
cd /var/www/kutoot

echo ">>> Configuring .env..."
# Use .env.deploy from kutoot-devops if present (has SMS, Mail, etc.), else .env.example
if [ -f /home/ubuntu/.env.deploy ]; then
  cp /home/ubuntu/.env.deploy .env
  echo "    Using env-templates/.env from kutoot-devops"
elif [ -f .env.example ]; then
  cp .env.example .env
elif [ -f env.example ]; then
  cp env.example .env
else
  echo "ERROR: No .env found. Copy env-templates/.env to server or ensure .env.example exists."
  exit 1
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

echo ">>> Generating keys..."
php artisan key:generate --force
php artisan jwt:secret --force 2>/dev/null || true

echo ">>> Building frontend assets..."
npm ci
npm run build

echo ">>> Running migrations..."
php artisan migrate --force 2>/dev/null || true

echo ">>> Caching config..."
php artisan config:cache
php artisan storage:link

echo ">>> Setting permissions..."
sudo chown -R www-data:www-data /var/www/kutoot
sudo chmod -R 775 /var/www/kutoot/storage
sudo chmod -R 775 /var/www/kutoot/bootstrap/cache

echo ""
echo "=== Deployment Complete ==="
echo "Test: http://kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com"
echo ""
echo "If DB_PASSWORD was wrong, run: nano /var/www/kutoot/.env"
