locals {
  backup_plan_enabled = var.point_in_time_recovery_enabled
}

resource "aws_backup_plan" "main" {
  count = local.backup_plan_enabled ? 1 : 0

  name = "prsdb-backup-plan-${var.environment_name}"

  dynamic "rule" {
    for_each = var.point_in_time_recovery_enabled ? [1] : []

    content {
      rule_name         = "continuous-pitr"
      target_vault_name = aws_backup_vault.main.name
      # Continuous backups capture changes as they happen; this daily run only discards history older than the retention period
      schedule                 = "cron(0 1 * * ? *)"
      start_window             = 60
      completion_window        = 1440
      enable_continuous_backup = true

      lifecycle {
        delete_after = var.backup_retention_days
      }
    }
  }
}

resource "aws_backup_selection" "s3_buckets" {
  count = local.backup_plan_enabled ? 1 : 0

  name         = "prsdb-s3-buckets-${var.environment_name}"
  plan_id      = aws_backup_plan.main[0].id
  iam_role_arn = aws_iam_role.backup.arn
  resources    = var.s3_bucket_arns

  depends_on = [
    aws_iam_role_policy_attachment.backup,
    aws_iam_role_policy_attachment.restores,
    aws_iam_role_policy_attachment.s3_backup,
    aws_iam_role_policy_attachment.s3_restore,
    aws_iam_role_policy_attachment.backup_vault_kms,
  ]
}
