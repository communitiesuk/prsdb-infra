output "backup_vault_kms_key_arns" {
  value       = local.backup_vault_kms_key_arns
  description = "ARNs of the KMS keys encrypting the backup vaults"
}

output "backup_role_arn" {
  value       = aws_iam_role.backup.arn
  description = "ARN of the IAM role AWS Backup uses to back up and restore resources"
}
