# Auto-Deploy on New Instances (User Data)

When Auto Scaling launches a **new** instance, it automatically:

1. Installs Nginx, PHP 8.4, Composer
2. Clones Laravel from GitHub
3. Runs `composer install`
4. Configures `.env` with DB connection
5. Deploys to `/var/www/kutoot`

**Result:** New instances are ready to serve traffic with Laravel at `/var/www/kutoot` – no manual SSH deploy needed.

## Configuration

Add to `terraform/02-asg/terraform.tfvars`:

```hcl
db_host     = "172.31.45.181"
db_database = "kutoot_backend"
db_username = "admin"
db_password = "YOUR_ACTUAL_MYSQL_PASSWORD"
laravel_repo_url = "https://github.com/kutoot-dev/kutoot.git"
```

- **db_password** – Required. Use your real MySQL password.
- **laravel_repo_url** – For private repo: `https://x-access-token:TOKEN@github.com/kutoot-dev/kutoot.git`

## Apply Changes

After adding `db_password` to terraform.tfvars:

```bash
cd terraform/02-asg
terraform apply -auto-approve
```

This updates the Launch Template. **New** instances (scale-out, replacement) will use it. Existing instances are unchanged.

## Health Check Grace Period

User data takes ~5–10 minutes. Set grace period to at least **600** (10 min). Terraform default is 14400 (4 hours).

## Verify

1. Scale ASG to 2 (or trigger instance refresh).
2. Wait ~10 minutes.
3. Check new instance: `ssh -i kutoot-sql.pem ubuntu@<NEW_IP>` then `ls /var/www/kutoot`.
4. Check logs: `sudo cat /var/log/kutoot-userdata.log`
