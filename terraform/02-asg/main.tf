# -----------------------------------------------------------------------------
# Remote state from 01-alb
# -----------------------------------------------------------------------------

data "terraform_remote_state" "alb" {
  backend = "local"
  config = {
    path = "${path.module}/../01-alb/terraform.tfstate"
  }
}

locals {
  name = "${var.project_name}-${var.environment}"
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
  count                    = var.mysql_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.laravel.id
  security_group_id        = var.mysql_security_group_id
  description              = "MySQL from Laravel"
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

  vpc_security_group_ids = [aws_security_group.laravel.id]

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
  health_check_type   = "ELB"
  health_check_grace_period = 1200

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
