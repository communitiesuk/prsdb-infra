resource "aws_appautoscaling_target" "webapp" {
  count              = var.task_definition_created ? 1 : 0
  max_capacity       = 15
  min_capacity       = 2
  resource_id        = "service/${module.ecs_service[0].ecs_cluster_name}/${module.ecs_service[0].ecs_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  # Scheduled actions temporarily change the minimum; don't undo them on apply.
  lifecycle {
    ignore_changes = [min_capacity]
  }
}

resource "aws_appautoscaling_policy" "webapp_cpu" {
  count              = var.task_definition_created ? 1 : 0
  name               = "production-webapp-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.webapp[0].resource_id
  scalable_dimension = aws_appautoscaling_target.webapp[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.webapp[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_out_cooldown = 60
    scale_in_cooldown  = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

locals {
  registration_deadlines = {
    west_midlands        = "2027-03-14"
    east_of_england      = "2027-04-14"
    east_midlands        = "2027-05-14"
    south_east           = "2027-06-14"
    yorkshire_and_humber = "2027-07-14"
    north_west           = "2027-08-14"
    north_east           = "2027-09-14"
    london               = "2027-10-14"
    south_west           = "2027-11-14"
  }

  deadline_scaling_actions = merge(
    { for region, date in local.registration_deadlines : "${region}-raise" => {
      date         = formatdate("YYYY-MM-DD", timeadd("${date}T00:00:00Z", "-24h"))
      time         = "07:00:00"
      min_capacity = 6
    } },
    { for region, date in local.registration_deadlines : "${region}-restore" => {
      date         = formatdate("YYYY-MM-DD", timeadd("${date}T00:00:00Z", "24h"))
      time         = "01:00:00"
      min_capacity = 2
    } },
  )
}

resource "aws_appautoscaling_scheduled_action" "deadline" {
  for_each = var.task_definition_created ? local.deadline_scaling_actions : {}

  name               = "production-webapp-${each.key}"
  resource_id        = aws_appautoscaling_target.webapp[0].resource_id
  scalable_dimension = aws_appautoscaling_target.webapp[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.webapp[0].service_namespace
  schedule           = "at(${each.value.date}T${each.value.time})"
  timezone           = "Europe/London"

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = 15
  }
}
