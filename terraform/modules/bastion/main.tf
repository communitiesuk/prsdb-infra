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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_instance" "bastion" {
  ami             = "ami-00710ab5544b60cf7"
  instance_type   = "t2.micro"
  subnet_id       = var.bastion_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_bastion.name
}