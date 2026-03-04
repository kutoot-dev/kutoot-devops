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

# Check if Laravel files exist
if [ ! -f /home/ubuntu/artisan ]; then
    echo "ERROR: Laravel files not found in /home/ubuntu/"
    echo "Run this from Windows first:"
    echo '  scp -i "kutoot-sql.pem" -r "C:\Users\aDMIN\Desktop\kutoot_backend\*" ubuntu@<INSTANCE-IP>:/home/ubuntu/'
    exit 1
fi

echo ">>> Installing PHP 8.2, Nginx, Composer..."
sudo add-apt-repository ppa:ondrej/php -y 2>/dev/null || true
sudo apt update -qq
sudo DEBIAN_FRONTEND=noninteractive apt install -y nginx php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl php8.2-zip php8.2-gd php8.2-bcmath unzip git

echo ">>> Installing Composer..."
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo update-alternatives --set php /usr/bin/php8.2 2>/dev/null || true

echo ">>> Setting up Nginx..."
sudo mkdir -p /var/www/kutoot-backend/public
echo "OK" | sudo tee /var/www/kutoot-backend/public/index.html > /dev/null

sudo tee /etc/nginx/sites-available/kutoot-backend > /dev/null << 'NGINX'
server {
    listen 80;
    root /var/www/kutoot-backend/public;
    index index.php index.html;
    server_name _;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/kutoot-backend /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart php8.2-fpm nginx

echo ">>> Copying Laravel files..."
sudo cp -r /home/ubuntu/* /var/www/kutoot-backend/
cd /var/www/kutoot-backend

echo ">>> Configuring .env..."
cp .env.example .env
sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
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
sudo chown -R www-data:www-data /var/www/kutoot-backend
sudo chmod -R 775 /var/www/kutoot-backend/storage
sudo chmod -R 775 /var/www/kutoot-backend/bootstrap/cache

echo ""
echo "=== Deployment Complete ==="
echo "Test: http://kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com"
echo ""
echo "If DB_PASSWORD was wrong, run: nano /var/www/kutoot-backend/.env"
