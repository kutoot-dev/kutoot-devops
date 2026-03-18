# -----------------------------------------------------------------------------
# MySQL EC2 - Run FIRST (before 01-alb, 02-asg)
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
  vpc_id     = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  vpc_cidr   = var.vpc_id != "" ? data.aws_vpc.selected[0].cidr_block : data.aws_vpc.default[0].cidr_block
  name       = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# MySQL Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "mysql" {
  name        = "${local.name}-mysql-sg"
  description = "Security group for Kutoot MySQL EC2"
  vpc_id      = local.vpc_id

  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
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
    Name = "${local.name}-mysql-sg"
  }
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
  ami                    = data.aws_ami.ubuntu.id
  instance_type           = var.instance_type
  key_name                = var.key_name
  vpc_security_group_ids  = [aws_security_group.mysql.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    db_database = var.db_database
    db_username = var.db_username
    db_password = var.db_password
  }))

  tags = {
    Name = "${local.name}-mysql"
  }
}
