output "performance_runner_access_role_arn" {
  description = "ARN of the performance runner network access role"
  value       = try(aws_iam_role.performance_runner_access[0].arn, null)
}

output "one_login_simulator_mirror_role_arn" {
  description = "ARN of the NFT One Login simulator image mirror role"
  value       = try(aws_iam_role.one_login_simulator_mirror[0].arn, null)
}
