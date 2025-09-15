resource "aws_cloudwatch_event_rule" "ecs_events" {
  name        = "${var.environment_name}-ecs-events"
  description = "Capture ECS events"
  event_pattern = jsonencode({
    "source" : ["aws.ecs"],
  })
}

resource "aws_cloudwatch_log_group" "ecs_events" {
  name              = "${var.environment_name}-ecs-events"
  retention_in_days = 1
}

resource "aws_cloudwatch_event_target" "ecs_events_to_logs" {
  target_id = "${var.environment_name}-ecs-events-to-logs"
  rule      = aws_cloudwatch_event_rule.ecs_events.name
  arn       = aws_cloudwatch_log_group.ecs_events.arn
}