# -----------------------------------------------------------------------------
# MySQL Automated Backups - S3 + IAM
# Run after 00-mysql. Attach IAM role to MySQL instance for S3 uploads.
# -----------------------------------------------------------------------------

variable "project_name" {
  type    = string
  default = "kutoot"
}

variable "environment" {
  type    = string
  default = "prod"
}

locals {
  name   = "${var.project_name}-${var.environment}"
  bucket = "${var.project_name}-mysql-backups"
}

# S3 bucket for MySQL dumps
resource "aws_s3_bucket" "mysql_backups" {
  bucket = local.bucket

  tags = {
    Name = "${local.name}-mysql-backups"
  }
}

resource "aws_s3_bucket_versioning" "mysql_backups" {
  bucket = aws_s3_bucket.mysql_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mysql_backups" {
  bucket = aws_s3_bucket.mysql_backups.id

  rule {
    id     = "expire-old"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# IAM role for MySQL EC2
resource "aws_iam_role" "mysql_backup" {
  name = "${local.name}-mysql-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "mysql_backup" {
  name = "s3-backup"
  role = aws_iam_role.mysql_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.mysql_backups.arn,
        "${aws_s3_bucket.mysql_backups.arn}/*"
      ]
    }]
  })
}

# Session Manager (no SSH required on MySQL instance)
resource "aws_iam_role_policy_attachment" "mysql_backup_ssm" {
  role       = aws_iam_role.mysql_backup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "mysql_backup" {
  name = "${local.name}-mysql-backup-profile"
  role = aws_iam_role.mysql_backup.name
}
