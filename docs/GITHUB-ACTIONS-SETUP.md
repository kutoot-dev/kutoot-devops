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
| `ENV_FILE_CONTENT` | If no env-templates/.env | Full `.env` content (instances use S3 .env) |
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
4. Run tests (optional, continues on failure)
5. Configure AWS
6. Create tarball (matches upload-kutoot-to-s3.ps1 format)
7. Upload `kutoot.tar.gz` to S3
8. Upload `.env` from env-templates or `ENV_FILE_CONTENT` secret
9. Start instance refresh on the ASG

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Kutoot app not found" | Ensure kutoot-dev/kutoot is accessible. Add `REPO_ACCESS_TOKEN` if private. |
| "Access Denied" on S3 | Check IAM has `s3:PutObject` on the bucket. |
| Instance refresh fails | Check IAM has `autoscaling:StartInstanceRefresh`. |
| No .env uploaded | Add `env-templates/.env` in kutoot-devops or set `ENV_FILE_CONTENT` secret. |
