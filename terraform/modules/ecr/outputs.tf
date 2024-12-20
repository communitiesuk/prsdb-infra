output "task_execution_role_arn" {
  value       = aws_iam_role.task_execution.arn
  description = "Role to be used by ECS to execute tasks from the ecr repository"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.main.repository_url
  description = "URL of the ecr repository"
}

output "push_ecr_image_policy_arn" {
  value       = aws_iam_policy.push_images.arn
  description = "iam policy allowing pushing to the ecr repository"
}