output "mysql_instance_id" {
  description = "MySQL EC2 instance ID"
  value       = aws_instance.mysql.id
}

output "mysql_private_ip" {
  description = "MySQL private IP (use for DB_HOST in Laravel)"
  value       = aws_instance.mysql.private_ip
}

output "mysql_public_ip" {
  description = "MySQL public IP (for SSH)"
  value       = aws_instance.mysql.public_ip
}

output "mysql_security_group_id" {
  description = "MySQL security group ID (use in 02-asg mysql_security_group_id)"
  value       = aws_security_group.mysql.id
}
