output "bucket_name" {
  description = "S3 bucket name for Laravel uploads"
  value       = aws_s3_bucket.laravel.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.laravel.arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain (for AWS_URL in .env)"
  value       = aws_s3_bucket.laravel.bucket_regional_domain_name
}
