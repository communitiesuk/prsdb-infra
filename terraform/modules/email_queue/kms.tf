resource "aws_kms_key" "email_queue" {
  description             = "${var.environment_name}-prsdb-email-queue"
  enable_key_rotation     = true
  rotation_period_in_days = 180
}

resource "aws_kms_alias" "email_queue" {
  target_key_id = aws_kms_key.email_queue.key_id
  name          = "alias/${var.environment_name}-prsdb-email-queue"
}
