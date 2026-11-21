resource "aws_backup_vault" "main" {
  name        = "prsdb-backup-vault-${var.environment_name}"
  kms_key_arn = aws_kms_key.backup_vault.arn

  depends_on = [aws_kms_key_policy.backup_vault]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_backup_vault_policy" "main" {
  backup_vault_name = aws_backup_vault.main.name
  policy            = data.aws_iam_policy_document.backup_vault.json
}

data "aws_iam_policy_document" "backup_vault" {
  statement {
    sid    = "DenyRecoveryPointDeletion"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "backup:DeleteRecoveryPoint",
      "backup:UpdateRecoveryPointLifecycle",
    ]

    resources = ["*"]
  }
}
