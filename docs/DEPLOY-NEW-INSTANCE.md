# Deploy to New Instance (When Scaling or Instance Replaced)

When ASG launches a new instance, User Data may fail (private repo). Use this flow instead.

## Prerequisites

- Kutoot repo cloned locally: `C:\Users\aDMIN\Desktop\kutoot`
- kutoot-sql.pem in a known location

## One Command

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\scripts
.\deploy-to-new-instance.ps1 <NEW_INSTANCE_IP> root123
```

Example:
```powershell
.\deploy-to-new-instance.ps1 3.111.42.47 root123
```

## What It Does

1. SCPs Laravel code from your machine to `/home/ubuntu/`
2. SCPs deploy script
3. SSHs and runs deploy (nginx, PHP, composer, .env, permissions)
4. Instance becomes healthy → ALB starts sending traffic

## dev.kutoot.com – No Manual Switch

**dev.kutoot.com** → Cloudflare → **ALB** → Target Group → **All healthy instances**

- When instance 1 goes down, ALB stops sending to it
- Instance 2 gets all traffic automatically
- No DNS or Cloudflare changes needed

## Manual Steps (if script fails)

```powershell
# 1. Copy code
scp -i kutoot-sql.pem -r C:\Users\aDMIN\Desktop\kutoot\* ubuntu@<IP>:/home/ubuntu/

# 2. Copy deploy script
scp -i kutoot-sql.pem scripts\deploy-laravel-ec2.sh ubuntu@<IP>:~/

# 3. SSH and run
ssh -i kutoot-sql.pem ubuntu@<IP>
chmod +x deploy-laravel-ec2.sh
./deploy-laravel-ec2.sh root123
```
