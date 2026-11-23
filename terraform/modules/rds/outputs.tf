output "rds_security_group_id" {
  value       = aws_security_group.main.id
  description = "The id of the rds security group"
}

output "database_username_ssm_parameter_arn" {
  value       = aws_ssm_parameter.database_username.arn
  description = "The ARN of the SSM parameter containing the database username"
}

output "database_url_ssm_parameter_arn" {
  value       = aws_ssm_parameter.database_url.arn
  description = "The ARN of the SSM parameter containing the database URL"
}

output "database_identifier" {
  value       = aws_db_instance.main.identifier
  description = "The identifier of the DB instance"
}

output "backup_replication_kms_key_arn" {
  value       = aws_kms_key.backup_replication.arn
  description = "The ARN of the eu-west-1 KMS key used to encrypt replicated automated backups"
}
