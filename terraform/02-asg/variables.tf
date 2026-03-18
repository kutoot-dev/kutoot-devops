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

variable "use_mysql_module" {
  description = "When true, get MySQL SG and db_host from 00-mysql. Run 00-mysql first."
  type        = bool
  default     = false
}

variable "mysql_security_group_id" {
  description = "MySQL EC2 security group ID (when use_mysql_module=false)"
  type        = string
  default     = ""
}

variable "db_host" {
  description = "MySQL host for Laravel (when use_mysql_module=false)"
  type        = string
  default     = "172.31.45.181"
}

# --- For User Data (auto-deploy on new instances) ---
variable "db_database" {
  description = "MySQL database name"
  type        = string
  default     = "kutoot_backend"
}

variable "db_username" {
  description = "MySQL username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "MySQL password (stored in user data - use tfvars, never commit)"
  type        = string
  sensitive   = true
}

variable "laravel_repo_url" {
  description = "Laravel repo URL for git clone (use HTTPS; for private: https://x-access-token:TOKEN@github.com/owner/repo.git)"
  type        = string
  default     = "https://github.com/kutoot-dev/kutoot_backend.git"
}
