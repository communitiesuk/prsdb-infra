output "arn" {
  value       = aws_ecs_service.main.id
  description = "The ARN of the ECS service"
}

output "name" {
  value       = aws_ecs_service.main.name
  description = "The name of the ECS service"
}
