# MySQL private rebuild (post-incident hardening)

Terraform in `terraform/00-mysql` now:

- Does **not** open **3306 to the whole VPC**; only **02-asg** `mysql_from_laravel` adds **3306 from the Laravel security group**.
- Sets **`associate_public_ip_address = false`** (no public IPv4 on the DB).
- Uses **SSM Session Manager** via either the **06-mysql-backups** instance profile (includes SSM + S3) or a minimal SSM-only profile.
- Binds MySQL to the instance **private IP** (IMDS) instead of `0.0.0.0`.
- Defaults app DB user to **`kutoot_app`** (scoped grant on `db_database` only).

## Apply order

1. **`terraform/06-mysql-backups`** — ensures `kutoot-prod-mysql-backup-profile` exists and attaches **AmazonSSMManagedInstanceCore** to the backup role.
2. **`terraform/00-mysql`** — set in `terraform.tfvars`:
   - `instance_profile_name = "kutoot-prod-mysql-backup-profile"`
   - `db_password` = strong secret
   - Optional: `mysql_bootstrap_ingress_cidrs = ["YOUR.PUBLIC.IP/32"]` only while importing dumps from your machine; **remove** after cutover and `terraform apply` again.
   - Optional: `subnet_id` for a **private subnet with NAT** (recommended for production).
3. **`terraform/02-asg`** — `mysql_security_group_id` must match **00-mysql** output `mysql_security_group_id`. Use `use_mysql_module = true` + local state path to **00-mysql**, or set `db_host` to the new **`mysql_private_ip`** after 00-mysql apply.
4. **`env-templates/.env`** / GitHub **`DB_PASSWORD`** — set `DB_USERNAME=kutoot_app` (or your chosen `db_username`) and matching password; deploy / instance refresh.

## Admin access

Use **AWS Systems Manager → Session Manager** to open a shell on the MySQL instance; avoid SSH on `22` unless `enable_ssh = true` and a narrow `allowed_ssh_cidr`.
