output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.laravel.name
}

output "laravel_security_group_id" {
  description = "Laravel EC2 security group ID"
  value       = aws_security_group.laravel.id
}

output "deploy_config_bucket" {
  description = "S3 bucket for .env (upload env-templates/.env for auto-deploy)"
  value       = aws_s3_bucket.deploy_config.id
}
