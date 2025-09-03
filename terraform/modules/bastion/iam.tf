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
  name = "${var.environment_name}-bastion-instance-profile"
  role = aws_iam_role.ssm_bastion.name
}

resource "aws_iam_role_policy_attachment" "ssm_bastion_maintenance_window" {
  role       = aws_iam_role.ssm_bastion.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

data "aws_iam_policy_document" "ssm_send_command_policy_doc" {
  statement {
    actions   = ["ssm:SendCommand"]
    effect    = "Allow"
    resources = ["arn:aws:ssm:us-east-1::document/AWS-RunRemoteScript"]
  }
}

resource "aws_iam_role_policy" "ssm_bastion_send_command_role_policy" {
  name   = "${var.environment_name}-bastion-send-command-role-policy"
  role   = aws_iam_role.ssm_bastion.name
  policy = data.aws_iam_policy_document.ssm_send_command_policy_doc.json
}

# Allows running SSM remote commands on EC2 instances
data "aws_iam_role" "aws_service_role_for_ssm" {
  name = "${var.environment_name}-aws-service-role-for-ssm"
}