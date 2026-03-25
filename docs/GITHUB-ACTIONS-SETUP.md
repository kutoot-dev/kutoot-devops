# GitHub Actions CI/CD Setup

When a pull request is merged to `main`, the workflow automatically builds and deploys to the backend (S3 + EC2 instance refresh).

## Architecture

```
PR merged → push to main → Deploy workflow runs → Upload to S3 → Instance refresh
```

- **kutoot-devops**: Hosts the main deploy workflow. Deploys on push to its own `main` or when triggered by `repository_dispatch`.
- **kutoot** (app repo): Optionally runs a trigger workflow that sends `repository_dispatch` to kutoot-devops when kutoot's `main` is pushed.

## One-Time Setup

### 1. Add secrets to kutoot-devops

Go to **GitHub → kutoot-devops → Settings → Secrets and variables → Actions**.

Add these **repository secrets**:

| Secret | Required | Description |
|--------|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Yes | AWS IAM access key for S3 + Auto Scaling |
| `AWS_SECRET_ACCESS_KEY` | Yes | AWS IAM secret key |
| `DEPLOY_BUCKET` | Yes | S3 bucket name (e.g. `kutoot-prod-deploy-408110214942`) |
| `ASG_NAME` | No | Auto Scaling Group name (default: `kutoot-prod-asg`) |
| `REPO_ACCESS_TOKEN` | **Yes** | PAT with `repo` scope to checkout kutoot (GITHUB_TOKEN cannot access other repos) |
| `DB_PASSWORD` | If not using Terraform | DB password injected into uploaded `.env`. Use when `db_password` is empty in Terraform. |
| `ENV_FILE_CONTENT` | If no env-templates/.env | Full `.env` content. Use **LF line endings only** (no CRLF/^M). Set `DB_USERNAME` (e.g. `kutoot_app`) and `DB_PASSWORD` to match hardened MySQL. |
| `COMPOSER_AUTH` | If private Composer packages | JSON auth for composer |

### 2. Get deploy bucket and ASG name

From your local machine (after `terraform apply` in 02-asg):

```powershell
cd terraform/02-asg
terraform output deploy_config_bucket
terraform output asg_name
```

Use those values for the secrets.

### 3. (Optional) Trigger deploy from kutoot app repo

To deploy when PRs are merged to **kutoot** (the app), add a trigger workflow in the kutoot repo:

1. Create `kutoot/.github/workflows/trigger-deploy.yml` (copy from kutoot-devops `.github/workflows-templates/kutoot-trigger-deploy.yml`)

2. In **kutoot** repo, add secret: `DEVOPS_TRIGGER_TOKEN`
   - Create a PAT (Fine-grained or classic) with `repo` scope
   - Must have admin or write access to kutoot-devops
   - Use it as `DEVOPS_TRIGGER_TOKEN`

3. Update the curl URL in the template if your kutoot-devops repo has a different path.

## Workflow Triggers

| Trigger | When it runs |
|---------|--------------|
| `push` to `main` | Any PR merged to kutoot-devops |
| `repository_dispatch` | When kutoot sends the event (after merge to kutoot main) |
| `workflow_dispatch` | Manual run from Actions tab |

## What the workflow does

1. Checkout kutoot-devops and kutoot (app)
2. Validate Kutoot (artisan exists)
3. Install PHP + Composer, Node + npm
4. Build frontend assets (`npm run build`)
5. Configure AWS
6. Create tarball (includes built assets; matches upload-kutoot-to-s3.ps1 format)
7. Upload `kutoot.tar.gz` to S3
8. Upload `.env` from env-templates or `ENV_FILE_CONTENT` secret
9. Start instance refresh on the ASG

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Kutoot app not found" | Ensure kutoot-dev/kutoot is accessible. Add `REPO_ACCESS_TOKEN` if private. |
| "Access Denied" on S3 | Check IAM has `s3:PutObject` on the bucket. |
| Instance refresh fails | Check IAM has `autoscaling:StartInstanceRefresh`. |
| No .env uploaded | Add `env-templates/.env` (LF line endings) or set `ENV_FILE_CONTENT` secret. |
| 500 / DB connection error | **Option A:** Set `db_password = "root123"` in `terraform/02-asg/terraform.tfvars`, run `terraform apply`. **Option B:** Leave `db_password` empty, add `DB_PASSWORD` secret (e.g. `root123`), ensure env-templates/.env or ENV_FILE_CONTENT has `DB_PASSWORD=...`. Use LF line endings (no CRLF). |
| "Refresh already in progress" | AWS allows only one refresh at a time. The running refresh will use the code you just uploaded when new instances boot. Wait for it to finish or cancel in the AWS Console. |
| New instances not spinning | Check ASG desired capacity is > 0. In AWS Console > EC2 > Auto Scaling Groups > your ASG: verify Desired/Min/Max. If Desired=0, set it to 1+. Check instance refresh status for failures. |

### If instances don't spin up

1. **AWS Console** → EC2 → Auto Scaling Groups → select your ASG
2. Ensure **Desired capacity** is at least 1
3. Open the **Instance refresh** tab and inspect status (Pending, InProgress, Successful, Failed)
4. If refresh failed: check EC2 **Launch template**, **User data** (downloads from S3), and **Security groups**
5. If refresh is stuck: cancel it and re-run the deploy workflow

### Fast instance replacement (~10–15 min)

The workflow uses `InstanceWarmup=300` (5 min). The ASG `health_check_grace_period` should be 600 (10 min) so new instances are checked sooner. If yours is 14400 (4 hours), run in `terraform/02-asg`:

```bash
terraform apply
```

Then re-run deploy. Old instances will be replaced with fresh ones in ~10–15 min.
