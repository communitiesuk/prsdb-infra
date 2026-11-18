output "log_group_arn" {
  description = "ARN of the cloudwatch log group"
  value       = aws_cloudwatch_log_group.main.arn
}

output "name" {
  description = "Name of the cloudwatch log group"
  value       = aws_cloudwatch_log_group.main.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the cloudwatch log group"
  value       = aws_kms_key.main.arn
}
