output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_url" {
  description = "URL to access the application"
  value       = var.certificate_arn != "" ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used by ALB"
  value       = local.subnet_ids
}

output "alb_access_logs_bucket" {
  description = "S3 bucket for ALB access logs (empty if logging disabled)"
  value       = var.enable_alb_access_logs ? aws_s3_bucket.alb_access_logs[0].bucket : ""
}
