locals {
  backup_vault_kms_key_arns = [aws_kms_key.backup_vault.arn]
}

resource "aws_kms_key" "backup_vault" {
  description             = "KMS key used to encrypt AWS Backup recovery points in eu-west-2."
  enable_key_rotation     = true
  rotation_period_in_days = 180

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "backup_vault" {
  name          = "alias/backup-vault-${var.environment_name}"
  target_key_id = aws_kms_key.backup_vault.key_id
}

resource "aws_kms_key_policy" "backup_vault" {
  key_id = aws_kms_key.backup_vault.id
  policy = data.aws_iam_policy_document.kms_backup_vault.json
}

data "aws_iam_policy_document" "kms_backup_vault" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = ["kms:*"]

    resources = [aws_kms_key.backup_vault.arn]
  }
}
