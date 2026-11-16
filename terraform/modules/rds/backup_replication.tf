resource "aws_kms_key" "backup_replication" {
  provider = aws.eu-west-1

  description         = "KMS key used to encrypt RDS automated backups replicated to eu-west-1."
  enable_key_rotation = true
}

resource "aws_kms_alias" "backup_replication" {
  provider = aws.eu-west-1

  name          = "alias/rds-backup-replication-${var.environment_name}"
  target_key_id = aws_kms_key.backup_replication.key_id
}

resource "aws_kms_key_policy" "backup_replication" {
  provider = aws.eu-west-1

  key_id = aws_kms_key.backup_replication.id
  policy = data.aws_iam_policy_document.kms_backup_replication.json
}

data "aws_iam_policy_document" "kms_backup_replication" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = ["kms:*"]

    resources = [aws_kms_key.backup_replication.arn]
  }
}

resource "aws_db_instance_automated_backups_replication" "main" {
  count    = var.cross_region_backup_replication_enabled ? 1 : 0
  provider = aws.eu-west-1

  source_db_instance_arn = aws_db_instance.main.arn
  retention_period       = var.backup_retention_period
  kms_key_id             = aws_kms_key.backup_replication.arn

  depends_on = [aws_kms_key_policy.backup_replication]
}
