resource "aws_kms_key" "main" {
  description             = var.log_group_name
  enable_key_rotation     = true
  rotation_period_in_days = 180

  tags = {
    "terraform-plan-read" = true
  }
}

resource "aws_kms_alias" "main" {
  target_key_id = aws_kms_key.main.key_id
  name          = "alias/${var.log_group_name}"
}
