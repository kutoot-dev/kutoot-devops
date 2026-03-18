variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "domain_name" {
  description = "Root domain name (e.g. kutoot.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID. Required when create_hosted_zone=false."
  type        = string
  default     = ""

  validation {
    condition     = var.create_hosted_zone || var.route53_zone_id != ""
    error_message = "Set create_hosted_zone=true to create a new zone, or provide route53_zone_id for existing zone."
  }
}

variable "create_hosted_zone" {
  description = "Create a new Route 53 hosted zone. Set to false if domain is already managed elsewhere."
  type        = bool
  default     = false
}

variable "create_apex_record" {
  description = "Create A record for apex domain (kutoot.com) in addition to www"
  type        = bool
  default     = true
}
