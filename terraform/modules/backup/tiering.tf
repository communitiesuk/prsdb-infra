locals {
  tiering_down_after_days = 60
}

# hashicorp/aws has no backup tiering resource yet
resource "aws_cloudcontrolapi_resource" "backup_vault_tiering" {
  type_name = "AWS::Backup::TieringConfiguration"

  desired_state = jsonencode({
    TieringConfigurationName = "prsdb_backup_vault_${var.environment_name}"
    BackupVaultName          = aws_backup_vault.main.name
    ResourceSelection = [
      {
        ResourceType              = "S3"
        Resources                 = ["*"]
        TieringDownSettingsInDays = local.tiering_down_after_days
      },
    ]
  })
}
