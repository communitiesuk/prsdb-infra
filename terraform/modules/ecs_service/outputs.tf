output "ecs_cluster_arn" {
  value       = aws_ecs_cluster.main.arn
  description = "The arn of the ecs cluster for this environment"
}

output "ecs_security_group_ids" {
  value = [aws_security_group.ecs.id]
  description = "List of security group IDs attached to the ECS tasks"
}