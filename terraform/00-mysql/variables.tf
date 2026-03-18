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
  description = "EC2 key pair for SSH"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH"
  type        = string
  default     = "0.0.0.0/0"
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
  description = "MySQL username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID (empty = default VPC)"
  type        = string
  default     = ""
}
