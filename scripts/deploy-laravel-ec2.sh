#!/bin/bash
# Kutoot Laravel Deployment Script - Run on EC2 after SSH login
# Prerequisite: Run scp from Windows first to copy Laravel files to /home/ubuntu/

set -e

# ============ CONFIGURE THESE ============
# Match terraform/02-asg db_* and MySQL (private IP changes per instance)
DB_HOST="172.31.39.112"
DB_DATABASE="kutoot_backend"
DB_USERNAME="kutoot_app"
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
  nginx nodejs supervisor \
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

# Increase worker_connections for load (default 768 not enough for 2000+ concurrent)
sudo sed -i 's/worker_connections [0-9]*/worker_connections 8192/' /etc/nginx/nginx.conf 2>/dev/null || true

sudo tee /etc/nginx/sites-available/kutoot-backend > /dev/null << 'NGINX'
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

sudo ln -sf /etc/nginx/sites-available/kutoot-backend /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart php8.4-fpm nginx

echo ">>> Copying Laravel files..."
sudo cp -r "$LARAVEL_SRC"/. /var/www/kutoot/
sudo chown -R ubuntu:ubuntu /var/www/kutoot
cd /var/www/kutoot

echo ">>> Configuring .env → /var/www/kutoot/.env..."
# env-templates/.env is SCP'd as ~/.env.deploy by deploy-to-new-instance.ps1 (required every deployment)
if [ -f /home/ubuntu/.env.deploy ]; then
  cp /home/ubuntu/.env.deploy .env
  echo "    OK: env-templates/.env deployed to /var/www/kutoot/.env"
elif [ -f .env.example ]; then
  cp .env.example .env
  echo "    WARN: .env.deploy not found - using .env.example (run deploy with -EnvPath)"
elif [ -f env.example ]; then
  cp env.example .env
  echo "    WARN: .env.deploy not found - using env.example"
else
  echo "ERROR: No .env found. Ensure deploy-to-new-instance.ps1 copies env-templates/.env"
  exit 1
fi
sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env
sed -i 's/APP_DEBUG=.*/APP_DEBUG=false/' .env
sed -i 's/APP_ENV=.*/APP_ENV=production/' .env
sed -i 's|APP_URL=.*|APP_URL=https://dev.kutoot.com|' .env

[ ! -f .env ] && { echo "ERROR: .env not in /var/www/kutoot"; exit 1; }

echo ">>> Running composer install..."
export HOME=${HOME:-/root}
export COMPOSER_HOME=${COMPOSER_HOME:-/root/.composer}
composer install --optimize-autoloader --no-dev --no-interaction

echo ">>> Generating keys..."
php artisan key:generate --force
php artisan jwt:secret --force 2>/dev/null || true

echo ">>> Building frontend assets..."
npm ci
npm run build

echo ">>> Running migrations..."
php artisan migrate --force 2>/dev/null || true

# Clear then rebuild Laravel caches after .env and schema are in place (required in prod).
echo ">>> Optimize (optimize:clear + optimize)..."
php artisan optimize:clear
php artisan optimize
php artisan storage:link

echo ">>> Setting up Laravel Scheduler (crontab)..."
(sudo crontab -u www-data -l 2>/dev/null | grep -v "artisan schedule:run" ; echo "* * * * * cd /var/www/kutoot && php artisan schedule:run >> /dev/null 2>&1") | sudo crontab -u www-data -

echo ">>> Setting up Supervisor (queue:work)..."
sudo apt-get install -y supervisor 2>/dev/null || true
sudo tee /etc/supervisor/conf.d/kutoot-worker.conf > /dev/null << 'SUPERVISOR'
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
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start kutoot-worker:*

echo ">>> Setting permissions..."
sudo chown -R www-data:www-data /var/www/kutoot
sudo chmod -R 775 /var/www/kutoot/storage
sudo chmod -R 775 /var/www/kutoot/bootstrap/cache

echo ""
echo "=== Deployment Complete ==="
echo "Test: http://kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com"
echo ""
echo "If DB_PASSWORD was wrong, run: nano /var/www/kutoot/.env"
