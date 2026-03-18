# Kutoot .env – Required Variables

Full list of environment variables for Kutoot Laravel backend. Use `env-templates/.env.example` as reference.

## Critical (must set for deployment)

| Variable | Description | Example |
|----------|-------------|---------|
| APP_KEY | Laravel encryption key | Run `php artisan key:generate` |
| APP_URL | Backend URL | https://www.kutoot.com |
| DB_HOST | MySQL host | 172.31.45.181 |
| DB_DATABASE | Database name | kutoot_backend |
| DB_USERNAME | DB user | admin |
| DB_PASSWORD | DB password | (secret) |

## AWS S3 (file uploads)

| Variable | Description |
|----------|-------------|
| AWS_BUCKET | kutoot-backend |
| AWS_DEFAULT_REGION | ap-south-1 |
| AWS_ACCESS_KEY_ID | IAM user key |
| AWS_SECRET_ACCESS_KEY | IAM user secret |

## Mail

| Variable | Description |
|----------|-------------|
| MAIL_USERNAME | SMTP user |
| MAIL_PASSWORD | SMTP password |

## Razorpay (payments)

| Variable | Description |
|----------|-------------|
| RAZORPAY_KEY_ID | Live key |
| RAZORPAY_KEY_SECRET | Live secret |
| RAZORPAY_WEBHOOK_SECRET | Webhook secret |

## SMS (Way2Mint)

| Variable | Description |
|----------|-------------|
| WAY2MINT_USERNAME | API username |
| WAY2MINT_PASSWORD | API password |
| WAY2MINT_PE_ID | Principal Entity ID |
| WAY2MINT_OTP_TEMPLATE_ID | OTP template |

## Backup .env securely

Store your real `.env` in a secure location (password manager, encrypted backup). Never commit it.

```powershell
# Backup (run from server)
scp -i kutoot-sql.pem ubuntu@<LARAVEL_IP>:/var/www/kutoot/.env ./backups/env-backup-$(Get-Date -Format 'yyyyMMdd').env
```
