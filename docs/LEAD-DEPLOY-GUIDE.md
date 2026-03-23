# Lead Deploy Guide – Kutoot Backend

Quick reference for deploying latest code to `dev.kutoot.com`.

---

## Prerequisites (one-time)

| Item | Where / How |
|------|-------------|
| **kutoot-devops** repo | `C:\Users\<YourUser>\Desktop\kutoot-devops` |
| **kutoot** (Laravel) repo | `C:\Users\<YourUser>\Desktop\kutoot` |
| **AWS CLI** | Configured with credentials for kutoot AWS account |
| **SSH key** | `C:\Users\<YourUser>\Desktop\kutoot-db\kutoot-sql.pem` (for manual deploy – get from team) |

**Folder structure:**
```
Desktop\
├── kutoot-devops\     ← this repo
├── kutoot\            ← Laravel backend repo
└── kutoot-db\         ← kutoot-sql.pem (SSH key)
```

**If your paths are different:**
```powershell
.\deploy-for-autoscale.ps1 -KutootPath "C:\Users\LeadName\Desktop\kutoot"
.\deploy-to-new-instance.ps1 <IP> root123 -KutootPath "C:\path\to\kutoot" -KeyPath "C:\path\to\kutoot-sql.pem"
```

---

## One-Click Deploy (recommended)

```powershell
cd C:\Users\<YourUser>\Desktop\kutoot-devops\scripts
.\deploy-complete.ps1
```

This does everything: uploads code + .env to S3, triggers instance refresh. New instances get full code and .env automatically. Wait ~30–60 min.

---

## Deploy Latest Code (manual steps)

### 1. Pull latest code

```powershell
cd C:\Users\<YourUser>\Desktop\kutoot
git pull origin main

cd C:\Users\<YourUser>\Desktop\kutoot-devops
git pull origin main
```

### 2. Deploy to S3 and optionally refresh instances

```powershell
cd C:\Users\<YourUser>\Desktop\kutoot-devops\scripts
.\deploy-for-autoscale.ps1
```

This uploads:
- Laravel code (from local `kutoot` folder)
- `.env` (from `env-templates/.env`)

### 3. (Optional) Replace running instances

To apply the new code to existing instances:

```powershell
aws autoscaling start-instance-refresh --auto-scaling-group-name kutoot-prod-asg
```

- Wait 30–60 minutes for the refresh to complete.
- New instances auto-deploy from S3 and serve traffic.

If you **skip** the refresh:
- New instances (e.g. on scale-out) will use the new code.
- Existing instances keep the old code until replaced.

---

## When to Update `.env`

1. Edit `kutoot-devops\env-templates\.env` with the new values.
2. Upload to S3:
   ```powershell
   cd C:\Users\<YourUser>\Desktop\kutoot-devops\scripts
   .\upload-env-to-s3.ps1
   ```
3. Run an instance refresh or wait for a scale-out so new instances pick up the changes.

---

## Manual Deploy to a Single Instance

If you need to deploy to a specific new instance (e.g. before it gets traffic):

```powershell
cd C:\Users\<YourUser>\Desktop\kutoot-devops\scripts
.\deploy-to-new-instance.ps1 <INSTANCE_IP> root123
```

- Replace `<INSTANCE_IP>` with the instance’s public IP.
- `root123` is the MySQL password (use the correct value).
- Requires `kutoot-sql.pem` in the path referenced by the script.

---

## What Runs on Each Deploy

- `composer install`
- `php artisan migrate`
- `php artisan optimize:clear`
- `php artisan optimize`
- Nginx + PHP config
- Laravel scheduler (cron)
- Supervisor queue workers

---

## Troubleshooting

| Issue | Check |
|-------|--------|
| Deploy fails | `.\deploy-for-autoscale.ps1` – confirm AWS CLI and S3 access |
| Instance refresh fails | Ensure no other refresh is running: `aws autoscaling describe-instance-refreshes --auto-scaling-group-name kutoot-prod-asg` |
| 404 on site | Nginx config and routing – see `AUTO-DEPLOY-SETUP.md` |
| Queue not working | SSH to instance: `sudo supervisorctl status kutoot-worker:*` |

---

## Quick Checklist

- [ ] Pull latest from `kutoot` and `kutoot-devops` (from Desktop or your paths)
- [ ] Update `env-templates/.env` if needed
- [ ] Run `.\deploy-for-autoscale.ps1`
- [ ] Run `aws autoscaling start-instance-refresh --auto-scaling-group-name kutoot-prod-asg` (if you want to replace instances)
- [ ] Wait for refresh and verify at `https://dev.kutoot.com`
