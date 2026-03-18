#!/bin/bash
# Fix Laravel permissions and caches - Run on EC2 after deployment
# Usage: chmod +x fix-laravel-permissions.sh && ./fix-laravel-permissions.sh

set -e

APP_DIR="/var/www/kutoot-backend"

echo "=== Fixing Laravel Permissions ==="

echo ">>> Setting ownership to www-data..."
sudo chown -R www-data:www-data "$APP_DIR"

echo ">>> Setting directory permissions (755)..."
sudo find "$APP_DIR" -type d -exec chmod 755 {} \;

echo ">>> Setting file permissions (644)..."
sudo find "$APP_DIR" -type f -exec chmod 644 {} \;

echo ">>> Setting writable permissions for storage and bootstrap/cache..."
sudo chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
sudo chown -R www-data:www-data "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"

echo ">>> Clearing Laravel caches..."
sudo -u www-data php "$APP_DIR/artisan" config:clear
sudo -u www-data php "$APP_DIR/artisan" cache:clear
sudo -u www-data php "$APP_DIR/artisan" config:cache

echo ">>> Restarting PHP-FPM and Nginx..."
sudo systemctl restart php8.2-fpm nginx

echo ">>> Testing..."
curl -I http://localhost/ || true

echo ""
echo "=== Done ==="
echo "Test in browser: http://kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com"
