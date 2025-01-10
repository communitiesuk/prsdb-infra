output "ecs_task_execution_role_arn" {
  value       = aws_iam_role.ecs_task_execution.arn
  description = "Role to be used by ECS to execute tasks from the ecr repository"
}

output "webapp_ecs_task_role_arn" {
  value       = aws_iam_role.webapp_ecs_task.arn
  description = "Role to be used by the ECS task definition"
}

output "webapp_ecs_task_role_name" {
  value       = aws_iam_role.webapp_ecs_task.name
  description = "Name of the ECS task role"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.main.repository_url
  description = "URL of the ecr repository"
}

output "push_ecr_image_policy_arn" {
  value       = aws_iam_policy.push_images.arn
  description = "iam policy allowing pushing to the ecr repository"
}