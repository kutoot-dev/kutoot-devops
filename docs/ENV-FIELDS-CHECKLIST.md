# Kutoot .env – Fields to Copy/Fill

Use this as a checklist when setting up `.env` on the server.

---

## Required for deployment (deploy script sets these)

| Variable | Example | Notes |
|----------|---------|-------|
| DB_HOST | 172.31.45.181 | MySQL private IP |
| DB_DATABASE | kutoot_backend | |
| DB_USERNAME | admin | |
| DB_PASSWORD | root123 | Set via deploy script |
| APP_ENV | production | |
| APP_DEBUG | false | |
| APP_URL | https://dev.kutoot.com | Deploy script sets this |

---

## Required for OTP (SMS)

| Variable | Example | Notes |
|----------|---------|-------|
| SMS_DRIVER | way2mint | Use `way2mint` for real SMS; `log` only logs |
| WAY2MINT_USERNAME | your_username | From Way2Mint dashboard |
| WAY2MINT_PASSWORD | your_password | |
| WAY2MINT_SENDER_ID | KUTOOT | |
| WAY2MINT_PE_ID | your_pe_id | Principal Entity ID |
| WAY2MINT_OTP_TEMPLATE_ID | your_template_id | |
| WAY2MINT_PROVIDER_PE_ID | | Optional |
| OTP_LENGTH | 6 | 4 or 6 digits |

---

## Required for S3 uploads

| Variable | Example | Notes |
|----------|---------|-------|
| AWS_ACCESS_KEY_ID | AKIA... | IAM user or use instance role |
| AWS_SECRET_ACCESS_KEY | ... | |
| AWS_DEFAULT_REGION | ap-south-1 | |
| AWS_BUCKET | kutoot-backend | |
| AWS_URL | https://kutoot-backend.s3.ap-south-1.amazonaws.com | |
| FILESYSTEM_DISK | s3 | |
| OBJECT_STORAGE_DRIVER | s3 | |

---

## Required for payments (Razorpay)

| Variable | Example | Notes |
|----------|---------|-------|
| RAZORPAY_KEY_ID | rzp_live_... | |
| RAZORPAY_KEY_SECRET | ... | |
| RAZORPAY_WEBHOOK_SECRET | ... | |
| PAYMENT_DEFAULT_GATEWAY | razorpay | |

---

## Optional – Mail (for email OTP)

| Variable | Example | Notes |
|----------|---------|-------|
| MAIL_MAILER | smtp | |
| MAIL_HOST | smtp.gmail.com | |
| MAIL_PORT | 587 | |
| MAIL_USERNAME | your@gmail.com | |
| MAIL_PASSWORD | app_password | Gmail app password |
| MAIL_FROM_ADDRESS | noreply@kutoot.com | |
| MAIL_FROM_NAME | Kutoot | |

---

## Optional – Other

| Variable | Example | Notes |
|----------|---------|-------|
| APP_KEY | base64:... | Run `php artisan key:generate` |
| LOG_VIEWER_EMAILS | it@kutoot.com | For log viewer access |
| FRONTEND_URL | https://frontend.kutoot.com | |
| CORS_ALLOWED_ORIGINS | https://frontend.kutoot.com,https://dev.kutoot.com | Comma-separated |

---

## Quick copy block (fill your values)

```
# Database
DB_HOST=172.31.45.181
DB_DATABASE=kutoot_backend
DB_USERNAME=admin
DB_PASSWORD=

# SMS (Way2Mint)
SMS_DRIVER=way2mint
WAY2MINT_USERNAME=
WAY2MINT_PASSWORD=
WAY2MINT_SENDER_ID=KUTOOT
WAY2MINT_PE_ID=
WAY2MINT_OTP_TEMPLATE_ID=
OTP_LENGTH=6

# AWS S3
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=ap-south-1
AWS_BUCKET=kutoot-backend
AWS_URL=https://kutoot-backend.s3.ap-south-1.amazonaws.com

# Razorpay
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=

# Mail (optional)
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_FROM_ADDRESS=noreply@kutoot.com
```
