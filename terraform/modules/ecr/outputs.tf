output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.main.repository_url
}

output "push_ecr_image_policy_arn" {
  value = aws_iam_policy.push_images.arn
}