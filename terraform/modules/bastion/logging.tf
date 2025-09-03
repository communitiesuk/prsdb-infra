resource "aws_cloudwatch_log_group" "bastion_log_group" {
  name              = "${var.environment_name}-bastion"
  retention_in_days = 60

  tags = {
    Application = var.environment_name
  }
}