variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "kutoot"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB (min 2 AZs). Leave empty for default VPC subnets."
  type        = list(string)
  default     = []
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. When set, adds HTTPS listener and redirects HTTP to HTTPS."
  type        = string
  default     = ""
}

variable "enable_deletion_protection" {
  description = "Protect ALB from accidental deletion (set false only when destroying stack)"
  type        = bool
  default     = true
}

variable "enable_alb_access_logs" {
  description = "Write ALB access logs to S3 (recommended before public launch)"
  type        = bool
  default     = true
}
