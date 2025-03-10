terraform {
  required_version = "~>1.9.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.environment_name}-bastion"
  description = "Security group for SSM bastion in ${var.environment_name}"

  vpc_id = var.main_vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow bastion access to vpc endpoints to allow for SSM"
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow bastion access to postgres port within the VPC"
  }
}

data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_bastion" {
  name               = "${var.environment_name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_bastion_attachment" {
  role       = aws_iam_role.ssm_bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_bastion" {
  name = "ec2_ssm_instance_profile"
  role = aws_iam_role.ssm_bastion.name
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "bastion" {
  count                  = length(var.bastion_subnet_ids)
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = var.bastion_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_bastion.name

  root_block_device {
    encrypted = true
  }
  metadata_options {
    http_tokens = "required"
  }
}