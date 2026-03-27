# Troubleshoot: 404 / User-Data Not Deploying

If you see **404 Not Found** from Nginx at dev.kutoot.com, user-data likely failed or didn't complete.

## 1. Quick check – did user-data finish?

```bash
curl -s https://dev.kutoot.com/userdata-status.txt
```

- **`userdata-complete`** – User-data finished. If you still get 404, the issue is Laravel routing or app config.
- **`userdata-failed`** – User-data failed partway. See step 2.
- **404** – User-data never ran, or failed very early (before Laravel was copied).

## 2. SSH and check the log

```bash
# Get instance IP from AWS Console → EC2 → Instances
ssh -i your-key.pem ubuntu@<INSTANCE_IP>

# Full user-data log
sudo cat /var/log/kutoot-userdata.log

# Cloud-init output (also has user-data)
sudo cat /var/log/cloud-init-output.log
```

Find the last successful line before the failure.

## 3. Frequent causes

| Symptom in log | Fix |
|----------------|-----|
| "S3 fetch failed" / "Access Denied" | Instance IAM role must have `s3:GetObject` on the deploy bucket. Check `terraform/02-asg` IAM policy. |
| "ERROR: Neither S3 code nor Git clone worked" | Ensure deploy workflow uploaded `kutoot.tar.gz` to S3. Run deploy again. |
| "ERROR: Git clone failed" | Private repo – add token to `laravel_repo_url` in `terraform.tfvars`. |
| composer/npm fails | Dependencies or build error. Check the exact error in the log. |
| Script exits silently | Check `/var/log/cloud-init-output.log` for the full trace. |

## 4. Update launch template and retry

After changing `terraform/02-asg/templates/user-data.sh`, apply and refresh:

```bash
cd terraform/02-asg
terraform apply -auto-approve
```

Then trigger a deploy (GitHub Actions → Run workflow) so new instances get the updated user-data.

## 5. Manual deploy (emergency)

If user-data keeps failing, deploy manually:

1. SSH to the instance.
2. Run the steps from `user-data.sh` by hand, or use `scripts/deploy-laravel-ec2.sh` if available.
3. See `docs/FIX-EMPTY-INSTANCE.md` for details.

## 6. `400 Request Header Or Cookie Too Large` (nginx)

Nginx rejects the request when the **Cookie** (or other headers) exceed its buffer limits. Laravel/Filament session cookies can grow after login.

**In this repo**, user-data installs:

- `/etc/nginx/conf.d/99-kutoot-large-headers.conf` (**http** context — applies to all vhosts)
- The same directives on `kutoot-backend` **server** block

**New instances** get this from user-data; **old instances** keep the old config until **instance refresh** or manual edit:

```bash
sudo tee /etc/nginx/conf.d/99-kutoot-large-headers.conf << 'EOF'
client_header_buffer_size 32k;
large_client_header_buffers 8 64k;
EOF
sudo nginx -t && sudo systemctl reload nginx
```

Also enable **ALB target group stickiness** (`terraform/01-alb`) if you run **multiple** app servers with **file** sessions — see [PRODUCTION-ALB-NGINX.md](PRODUCTION-ALB-NGINX.md).

If it still happens, reduce session payload in the app (avoid huge data in session) or inspect cookie size in DevTools → Application → Cookies.
