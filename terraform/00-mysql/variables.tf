variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "kutoot"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "prod"
}

variable "key_name" {
  description = "EC2 key pair name (optional if using SSM only)"
  type        = string
  default     = ""
}

variable "enable_ssh" {
  description = "If true, allow SSH from allowed_ssh_cidr. Prefer false + SSM."
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "CIDR for SSH when enable_ssh is true (never use 0.0.0.0/0)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "MySQL EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "db_database" {
  description = "Database name to create"
  type        = string
  default     = "kutoot_backend"
}

variable "db_username" {
  description = "MySQL application user (Laravel); GRANT only on db_database"
  type        = string
  default     = "kutoot_app"
}

variable "db_user_host" {
  description = "MySQL user host pattern (e.g. % or 172.31.%%). SG is primary access control."
  type        = string
  default     = "%"
}

variable "db_password" {
  description = "MySQL password for db_username"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID (empty = default VPC)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID for MySQL (empty = AWS default subnet in VPC). Prefer private subnet with NAT."
  type        = string
  default     = ""
}

variable "associate_public_ip_address" {
  description = "Must be false for DB tier (no public IPv4)"
  type        = bool
  default     = false
}

variable "mysql_bootstrap_ingress_cidrs" {
  description = "Optional /32 CIDRs for temporary 3306 during migration; remove after cutover and apply again"
  type        = list(string)
  default     = []
}

variable "instance_profile_name" {
  description = "Existing EC2 instance profile (e.g. kutoot-prod-mysql-backup-profile from 06-mysql-backups). If empty, creates SSM-only profile here."
  type        = string
  default     = ""
}
