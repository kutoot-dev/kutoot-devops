# OTP Not Coming – Fix Guide

## Why OTP is not coming

OTP is sent only when **all** of these are true:

1. **APP_ENV=production** (deploy script sets this)
2. **SMS_DRIVER=way2mint** (for phone login) – default is `log` which only logs and does not send
3. **Way2Mint credentials** are set in `.env`

## Quick fix: Configure SMS on server

### 1. SSH to Laravel instance

```powershell
ssh -i "C:\Users\aDMIN\Desktop\kutoot-db\kutoot-sql.pem" ubuntu@15.207.85.48
```

### 2. Edit .env

```bash
sudo nano /var/www/kutoot/.env
```

### 3. Update these values

```env
# Change from log to way2mint
SMS_DRIVER=way2mint

# Add your Way2Mint credentials (get from Way2Mint dashboard)
WAY2MINT_USERNAME=your_username
WAY2MINT_PASSWORD=your_password
WAY2MINT_SENDER_ID=KUTOOT
WAY2MINT_PE_ID=your_pe_id
WAY2MINT_OTP_TEMPLATE_ID=your_otp_template_id
```

### 4. Clear config cache

```bash
cd /var/www/kutoot
sudo -u www-data php artisan config:cache
```

---

## Temporary: Get OTP from logs (for testing)

If you don’t have Way2Mint yet, OTP is always logged. You can read it from the server:

```bash
ssh -i kutoot-sql.pem ubuntu@15.207.85.48
sudo tail -100 /var/www/kutoot/storage/logs/laravel.log | grep "OTP for"
```

That will show lines like: `OTP for mobile [6305468471]: 1234`

---

## Alternative: Email OTP

If you use **email** instead of phone, configure MAIL_* in `.env`:

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@kutoot.com"
MAIL_FROM_NAME="Kutoot"
```

Then login with email instead of phone.

---

## Summary

| Item | Current (likely) | Required for OTP |
|------|------------------|------------------|
| SMS_DRIVER | log | way2mint |
| WAY2MINT_* | empty | Valid credentials |
| APP_ENV | production | production |
