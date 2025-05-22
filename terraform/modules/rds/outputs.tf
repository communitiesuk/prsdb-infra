output "rds_security_group_id" {
  value       = aws_security_group.main.id
  description = "The id of the rds security group"
}

output "rds_iam_policy_arn" {
  value       = aws_iam_policy.rds_data_access.arn
  description = "The arn of the rds iam policy"
}
