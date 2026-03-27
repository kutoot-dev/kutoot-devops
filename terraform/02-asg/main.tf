# -----------------------------------------------------------------------------
# Remote state from 01-alb and optionally 00-mysql
# -----------------------------------------------------------------------------

data "terraform_remote_state" "alb" {
  backend = "local"
  config = {
    path = "${path.module}/../01-alb/terraform.tfstate"
  }
}

data "terraform_remote_state" "mysql" {
  count   = var.use_mysql_module ? 1 : 0
  backend = "local"
  config = {
    path = "${path.module}/../00-mysql/terraform.tfstate"
  }
}

locals {
  name                    = "${var.project_name}-${var.environment}"
  mysql_security_group_id = var.use_mysql_module ? data.terraform_remote_state.mysql[0].outputs.mysql_security_group_id : var.mysql_security_group_id
  db_host                 = var.use_mysql_module ? data.terraform_remote_state.mysql[0].outputs.mysql_private_ip : var.db_host
}

# -----------------------------------------------------------------------------
# Laravel EC2 Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "laravel" {
  name        = "${local.name}-laravel-sg"
  description = "Security group for Kutoot Laravel EC2"
  vpc_id      = data.terraform_remote_state.alb.outputs.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.alb.outputs.alb_security_group_id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-laravel-sg"
  }
}

# Allow Laravel to connect to MySQL
resource "aws_security_group_rule" "mysql_from_laravel" {
  count                    = local.mysql_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.laravel.id
  security_group_id        = local.mysql_security_group_id
  description              = "MySQL from Laravel"
}

# -----------------------------------------------------------------------------
# S3 Bucket for deploy config (.env) - private, instances download via IAM
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "deploy_config" {
  bucket = "${var.project_name}-${var.environment}-deploy-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.name}-deploy-config"
  }
}

resource "aws_s3_bucket_versioning" "deploy_config" {
  bucket = aws_s3_bucket.deploy_config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deploy_config" {
  bucket = aws_s3_bucket.deploy_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access - .env must stay private
resource "aws_s3_bucket_public_access_block" "deploy_config" {
  bucket = aws_s3_bucket.deploy_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny unencrypted (HTTP) API access — clients must use TLS
resource "aws_s3_bucket_policy" "deploy_config_deny_insecure" {
  bucket = aws_s3_bucket.deploy_config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.deploy_config.arn,
        "${aws_s3_bucket.deploy_config.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.deploy_config]
}

# -----------------------------------------------------------------------------
# IAM Role for EC2 instances to read .env from S3
# -----------------------------------------------------------------------------

resource "aws_iam_role" "laravel_instance" {
  name = "${local.name}-laravel-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "laravel_s3_deploy" {
  name = "read-deploy-config"
  role = aws_iam_role.laravel_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = [
          "${aws_s3_bucket.deploy_config.arn}/kutoot.env",
          "${aws_s3_bucket.deploy_config.arn}/kutoot.tar.gz"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "laravel" {
  name = "${local.name}-laravel-profile"
  role = aws_iam_role.laravel_instance.name
}

# -----------------------------------------------------------------------------
# Launch Template
# -----------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "laravel" {
  name_prefix   = "${local.name}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.laravel.name
  }

  vpc_security_group_ids = [aws_security_group.laravel.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    db_host          = local.db_host
    db_database      = var.db_database
    db_username      = var.db_username
    db_password      = var.db_password
    laravel_repo_url = var.laravel_repo_url
    env_s3_uri       = "s3://${aws_s3_bucket.deploy_config.id}/kutoot.env"
    code_s3_uri      = "s3://${aws_s3_bucket.deploy_config.id}/kutoot.tar.gz"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-laravel"
    }
  }

  tags = {
    Name = "${local.name}-launch-template"
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Group
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "laravel" {
  name                = "${local.name}-asg"
  vpc_zone_identifier = data.terraform_remote_state.alb.outputs.subnet_ids
  target_group_arns   = [data.terraform_remote_state.alb.outputs.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 600 # 10 min - enough for user-data (composer, npm, Laravel) to boot

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.laravel.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-laravel"
    propagate_at_launch = true
  }
}

# -----------------------------------------------------------------------------
# Scaling Policies
# -----------------------------------------------------------------------------

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${local.name}-scale-out"
  scaling_adjustment     = 2
  adjustment_type       = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.laravel.name
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.laravel.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${local.name}-scale-in"
  scaling_adjustment     = -1
  adjustment_type       = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.laravel.name
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${local.name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.laravel.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}
