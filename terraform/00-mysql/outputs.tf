output "mysql_instance_id" {
  description = "MySQL EC2 instance ID"
  value       = aws_instance.mysql.id
}

output "mysql_private_ip" {
  description = "MySQL private IP (use for DB_HOST in Laravel)"
  value       = aws_instance.mysql.private_ip
}

output "mysql_public_ip" {
  description = "Empty when associate_public_ip_address is false"
  value       = aws_instance.mysql.public_ip
}

output "mysql_security_group_id" {
  description = "MySQL security group ID (use in 02-asg mysql_security_group_id)"
  value       = aws_security_group.mysql.id
}

output "mysql_instance_profile" {
  description = "Instance profile attached to MySQL (SSM + optional external)"
  value       = var.instance_profile_name != "" ? var.instance_profile_name : aws_iam_instance_profile.mysql_ssm[0].name
}
