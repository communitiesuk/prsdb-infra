output "performance_runner_access_role_arn" {
  description = "ARN of the performance runner network access role"
  value       = try(aws_iam_role.performance_runner_access[0].arn, null)
}
