# AWS CLI Setup for Kutoot

## 1. Install AWS CLI

**Option A: Download installer**
- https://aws.amazon.com/cli/
- Run the MSI installer for Windows

**Option B: Using winget**
```powershell
winget install Amazon.AWSCLI
```

## 2. Configure credentials

```powershell
aws configure
```

You'll be prompted for:
- **AWS Access Key ID** – From IAM user (Security credentials → Create access key)
- **AWS Secret Access Key**
- **Default region** – `ap-south-1` (Mumbai)
- **Output format** – `json` (optional)

## 3. Verify

```powershell
aws sts get-caller-identity
```

Should show your Account ID and User ARN.

## 4. Run full inventory

```powershell
cd C:\Users\aDMIN\Desktop\kutoot-devops\scripts
.\aws-full-inventory.ps1
```

This creates:
- `docs/BACKEND-INVENTORY.md` – Human-readable inventory
- `backups/aws-inventory-YYYYMMDD_HHmm.json` – JSON backup

## 5. Run regularly

Run the inventory script weekly or after major changes. Keeps your recovery docs up to date.
