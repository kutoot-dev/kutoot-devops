output "bucket_name" {
  description = "S3 bucket for MySQL backups"
  value       = aws_s3_bucket.mysql_backups.id
}

output "instance_profile_name" {
  description = "IAM instance profile name (attach to MySQL EC2)"
  value       = aws_iam_instance_profile.mysql_backup.name
}
