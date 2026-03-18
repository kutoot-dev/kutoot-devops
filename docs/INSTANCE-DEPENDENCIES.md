# Laravel Instance – Dependencies & One-Shot Setup

Exact environment for Kutoot Laravel EC2 instances. Use this to replicate on new instances.

## Target Environment

| Component | Version |
|-----------|---------|
| OS | Ubuntu 22.04 |
| PHP | 8.4.x |
| Nginx | 1.18.x |
| Composer | 2.x |

## System Packages (apt)

```
nginx
php8.4-fpm php8.4-cli php8.4-mysql php8.4-mbstring php8.4-xml php8.4-curl
php8.4-zip php8.4-gd php8.4-bcmath php8.4-intl php8.4-opcache
unzip git
```

## PHP Extensions (from php -m)

bcmath, calendar, Core, ctype, curl, date, dom, exif, gd, hash, iconv, intl, json, libxml, mbstring, mysqli, mysqlnd, openssl, PDO, pdo_mysql, xml, zip, Zend OPcache

## Laravel Dependencies (composer show -D)

From kutoot `composer.json` – installed by `composer install`:

- dedoc/scramble, endroid/qr-code, fakerphp/faker
- filament/filament, filament/spatie-laravel-media-library-plugin
- inertiajs/inertia-laravel, laravel/boost, laravel/breeze, laravel/framework
- laravel/octane, laravel/pail, laravel/pint, laravel/sail, laravel/sanctum, laravel/tinker
- league/flysystem-aws-s3-v3, mockery/mockery, nativephp/mobile, nnjeim/world
- nunomaduro/collision, opcodesio/log-viewer, pestphp/pest, pestphp/pest-plugin-laravel
- razorpay/razorpay, spatie/laravel-activitylog, spatie/laravel-permission
- tightenco/ziggy

## One-Shot Setup

On a **fresh Ubuntu 22.04** instance:

### Option 1: From kutoot-devops repo

```bash
git clone git@github.com:sanjeev059/kutoot-devops.git
cd kutoot-devops/scripts
chmod +x deploy-laravel-ec2.sh
./deploy-laravel-ec2.sh YOUR_MYSQL_PASSWORD
```

### Option 2: Direct from GitHub (no clone)

```bash
curl -sSL https://raw.githubusercontent.com/sanjeev059/kutoot-devops/main/scripts/deploy-laravel-ec2.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh YOUR_MYSQL_PASSWORD
```

### Option 3: SCP + run (if no git on instance)

```powershell
# From Windows
scp -i kutoot-sql.pem scripts/deploy-laravel-ec2.sh ubuntu@<EC2_IP>:~/
scp -i kutoot-sql.pem -r kutoot/* ubuntu@<EC2_IP>:~/
```

```bash
# On EC2
chmod +x deploy-laravel-ec2.sh
./deploy-laravel-ec2.sh YOUR_MYSQL_PASSWORD
```

## What the Script Does

1. Installs Nginx, PHP 8.4 (+ extensions), Composer
2. Configures Nginx → `/var/www/kutoot/public`
3. Clones Laravel from git (or uses SCP'd files)
4. Runs `composer install --no-dev`
5. Configures `.env` (DB, APP_ENV=production)
6. Generates keys, caches config, sets permissions

## Verify After Setup

```bash
php -v          # PHP 8.4.x
composer -V     # Composer 2.x
nginx -v        # nginx/1.18.x
cd /var/www/kutoot && composer show -D
```
