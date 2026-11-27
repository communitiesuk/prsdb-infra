resource "aws_appautoscaling_target" "webapp" {
  count              = var.task_definition_created ? 1 : 0
  max_capacity       = var.webapp_scaling_max_capacity
  min_capacity       = var.webapp_scaling_min_capacity
  resource_id        = "service/${module.ecs_service[0].ecs_cluster_name}/${module.ecs_service[0].ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    precondition {
      condition     = var.webapp_scaling_min_capacity <= var.webapp_scaling_max_capacity
      error_message = "The minimum webapp capacity must not exceed the maximum."
    }
  }
}

resource "aws_appautoscaling_policy" "webapp_cpu" {
  count              = var.task_definition_created ? 1 : 0
  name               = "nft-webapp-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.webapp[0].resource_id
  scalable_dimension = aws_appautoscaling_target.webapp[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.webapp[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.webapp_scaling_cpu_target
    scale_out_cooldown = 60
    scale_in_cooldown  = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
