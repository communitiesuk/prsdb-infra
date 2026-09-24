output "service_arn" {
  description = "ARN of the simulator ECS service"
  value       = aws_ecs_service.simulator.id
}

output "service_name" {
  description = "Name of the simulator ECS service"
  value       = aws_ecs_service.simulator.name
}

output "target_group_arn" {
  description = "ARN of the simulator target group"
  value       = aws_lb_target_group.simulator.arn
}

output "task_security_group_id" {
  description = "ID of the simulator task security group"
  value       = aws_security_group.simulator.id
}

output "simulator_alb_security_group_id" {
  description = "ID of the simulator ALB security group"
  value       = var.simulator_alb_security_group_id
}
