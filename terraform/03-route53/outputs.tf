output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = local.zone_id
}

output "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (use in 01-alb certificate_arn variable)"
  value       = try(aws_acm_certificate.main[0].arn, "")
}

output "name_servers" {
  description = "Name servers for the hosted zone (update these at your domain registrar if create_hosted_zone=true)"
  value       = try(aws_route53_zone.main[0].name_servers, [])
}

output "www_url" {
  description = "URL for www subdomain (HTTPS when cert is created)"
  value       = local.zone_id != "" ? "https://www.${var.domain_name}" : ""
}

output "apex_url" {
  description = "URL for apex domain (HTTPS when cert is created)"
  value       = local.zone_id != "" && var.create_apex_record ? "https://${var.domain_name}" : ""
}
