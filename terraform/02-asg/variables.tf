variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Laravel"
  type        = string
  default     = "t3.medium"
}

variable "asg_min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 8
}

variable "asg_desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "mysql_security_group_id" {
  description = "MySQL EC2 security group ID (allow Laravel to connect)"
  type        = string
  default     = ""
}
