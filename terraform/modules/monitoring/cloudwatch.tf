resource "aws_cloudwatch_event_rule" "ecs_events" {
  name        = "${var.environment_name}-ecs-events"
  description = "Capture ECS events"

  event_pattern = jsonencode({
    "source" : ["aws.ecs"],
  })
}

module "ecs_events_log_group" {
  source = "../encrypted_log_group"

  log_group_name     = "${var.environment_name}-ecs-events"
  log_retention_days = 1
}

resource "aws_cloudwatch_event_target" "ecs_events_to_logs" {
  target_id = "${var.environment_name}-ecs-events-to-logs"
  rule      = aws_cloudwatch_event_rule.ecs_events.name
  arn       = module.ecs_events_log_group.log_group_arn
}