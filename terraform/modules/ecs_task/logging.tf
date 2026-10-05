locals {
  log_group_name = "${var.environment_name}-${var.task_name}"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "log_group" {
  description         = local.log_group_name
  enable_key_rotation = true

  tags = {
    "terraform-plan-read" = true
  }
}

resource "aws_kms_alias" "log_group" {
  target_key_id = aws_kms_key.log_group.key_id
  name          = "alias/${local.log_group_name}"
}

data "aws_iam_policy_document" "log_group_kms" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"]
    }
  }

  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = ["kms:*"]

    resources = [aws_kms_key.log_group.arn]
  }
}

resource "aws_kms_key_policy" "log_group" {
  key_id = aws_kms_key.log_group.key_id
  policy = data.aws_iam_policy_document.log_group_kms.json
}

resource "aws_cloudwatch_log_group" "webapp_log_group" {
  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = aws_kms_key.log_group.arn

  tags = {
    Application = var.environment_name
  }

  depends_on = [aws_kms_key_policy.log_group]
}
