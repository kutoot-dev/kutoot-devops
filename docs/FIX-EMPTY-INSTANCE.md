# Fix: New Instance Has No /var/www/kutoot

User Data likely failed (often due to **private GitHub repo**). Use one of these:

## Option 1: Manual Deploy (Quick Fix)

### Step 1: Copy Laravel code to the new instance

From your Windows machine (where you have the kutoot repo):

```powershell
cd C:\Users\aDMIN\Desktop\kutoot
scp -i kutoot-sql.pem -r * ubuntu@<NEW_INSTANCE_IP>:/home/ubuntu/
```

### Step 2: Copy and run deploy script

```powershell
scp -i kutoot-sql.pem C:\Users\aDMIN\Desktop\kutoot-devops\scripts\deploy-laravel-ec2.sh ubuntu@<NEW_INSTANCE_IP>:~/
```

### Step 3: SSH and run

```bash
ssh -i kutoot-sql.pem ubuntu@<NEW_INSTANCE_IP>
chmod +x deploy-laravel-ec2.sh
./deploy-laravel-ec2.sh YOUR_MYSQL_PASSWORD
```

---

## Option 2: Use GitHub Token (Fix User Data for Future Instances)

If `kutoot-dev/kutoot` is **private**, add a token to `terraform/02-asg/terraform.tfvars`:

```hcl
# Create token: GitHub → Settings → Developer settings → Personal access tokens
# Scope: repo
laravel_repo_url = "https://x-access-token:ghp_YOUR_TOKEN_HERE@github.com/kutoot-dev/kutoot.git"
```

Then apply:

```powershell
cd terraform/02-asg
terraform apply -auto-approve
```

Future new instances will clone successfully.

---

## Check What Went Wrong

On the new instance:

```bash
sudo cat /var/log/kutoot-userdata.log
# or
sudo cat /var/log/cloud-init-output.log
```

Look for "ERROR: Git clone failed" – that confirms a private repo issue.
