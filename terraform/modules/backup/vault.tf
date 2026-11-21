resource "aws_backup_vault" "main" {
  name        = "prsdb-backup-vault-${var.environment_name}"
  kms_key_arn = aws_kms_key.backup_vault.arn

  depends_on = [aws_kms_key_policy.backup_vault]

  lifecycle {
    prevent_destroy = true
  }
}
