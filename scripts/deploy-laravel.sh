#!/bin/bash
# Deploy Laravel to EC2 instance
# Usage: ./deploy-laravel.sh <EC2_IP> <KEY_PATH> <MYSQL_HOST>

set -e

EC2_IP=${1:-""}
KEY_PATH=${2:-""}
MYSQL_HOST=${3:-"127.0.0.1"}

if [ -z "$EC2_IP" ] || [ -z "$KEY_PATH" ]; then
  echo "Usage: $0 <EC2_IP> <KEY_PATH> [MYSQL_HOST]"
  echo "Example: $0 13.235.24.13 ~/.ssh/kutoot-sql.pem 172.31.45.181"
  exit 1
fi

echo "Deploying Laravel to $EC2_IP..."

# Install dependencies if not present
ssh -i "$KEY_PATH" ubuntu@$EC2_IP << 'ENDSSH'
  sudo apt update
  sudo apt install -y nginx php8.1-fpm php8.1-mysql php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip php8.1-gd php8.1-bcmath unzip git
  command -v composer >/dev/null || (curl -sS https://getcomposer.org/installer | php && sudo mv composer.phar /usr/local/bin/composer)
ENDSSH

echo "Copy Laravel code manually, then run:"
echo "  ssh -i $KEY_PATH ubuntu@$EC2_IP"
echo "  cd /var/www/kutoot-backend"
echo "  composer install --no-dev"
echo "  php artisan key:generate"
echo "  php artisan config:cache"
echo "  sudo systemctl restart nginx"
