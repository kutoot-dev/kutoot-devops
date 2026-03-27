# -----------------------------------------------------------------------------
# MySQL EC2 - Run FIRST (before 01-alb, 02-asg)
# 3306 is allowed ONLY via 02-asg mysql_from_laravel (Laravel SG -> this SG)
# -----------------------------------------------------------------------------

data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

data "aws_vpc" "selected" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  name   = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# MySQL Security Group — no VPC-wide MySQL; Laravel rule added in 02-asg
# -----------------------------------------------------------------------------

resource "aws_security_group" "mysql" {
  name        = "${local.name}-mysql-sg"
  description = "Security group for Kutoot MySQL EC2 (3306 from Laravel SG only via 02-asg)"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "SSH (prefer SSM; disable when possible)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_ssh_cidr]
    }
  }

  dynamic "ingress" {
    for_each = toset(var.mysql_bootstrap_ingress_cidrs)
    content {
      description = "Temporary bootstrap MySQL — remove CIDRs after cutover"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-mysql-sg"
  }
}

# -----------------------------------------------------------------------------
# IAM — SSM Session Manager (when not using external instance profile)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "mysql_ssm" {
  count = var.instance_profile_name == "" ? 1 : 0
  name  = "${local.name}-mysql-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.name}-mysql-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "mysql_ssm" {
  count      = var.instance_profile_name == "" ? 1 : 0
  role       = aws_iam_role.mysql_ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "mysql_ssm" {
  count = var.instance_profile_name == "" ? 1 : 0
  name  = "${local.name}-mysql-ec2-profile"
  role  = aws_iam_role.mysql_ssm[0].name
}

# -----------------------------------------------------------------------------
# MySQL EC2 Instance
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

resource "aws_instance" "mysql" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name != "" ? var.key_name : null
  subnet_id                   = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = var.associate_public_ip_address
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  iam_instance_profile        = var.instance_profile_name != "" ? var.instance_profile_name : aws_iam_instance_profile.mysql_ssm[0].name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    db_database      = var.db_database
    db_username      = var.db_username
    db_password_b64  = base64encode(var.db_password)
    db_user_host     = var.db_user_host
  }))

  lifecycle {
    precondition {
      condition     = !var.enable_ssh || (var.allowed_ssh_cidr != "" && var.allowed_ssh_cidr != "0.0.0.0/0")
      error_message = "When enable_ssh is true, set allowed_ssh_cidr to a specific /32 (never 0.0.0.0/0). Prefer enable_ssh = false and use SSM."
    }
  }

  tags = {
    Name = "${local.name}-mysql"
  }
}
