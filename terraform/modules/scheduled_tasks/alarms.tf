resource "aws_cloudwatch_metric_alarm" "task_invocation_failure" {
  alarm_name          = "${var.environment_name}-prsdb-task-invocation-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InvocationDroppedCount"
  namespace           = "AWS/Scheduler"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions = {
    "ScheduleGroup" = aws_scheduler_schedule_group.scheduled_tasks.name
  }

  alarm_description = <<-EOT
    EventBridge scheduler failed to start a scheduled ECS task.
    Check the dead letter queue ${aws_sqs_queue.scheduled_tasks_dead_letter_queue.name}
  EOT
  alarm_actions     = [aws_sns_topic.alarm_scheduled_tasks_topic.arn]
  ok_actions        = [aws_sns_topic.alarm_scheduled_tasks_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "scheduled_task_execution_failure" {
  alarm_name          = "${var.environment_name}-prsdb-scheduled-task-execution-failure"
  alarm_description   = "A scheduled ECS task ran but stopped with a non-zero exit code, so the job did not complete successfully."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = aws_cloudwatch_log_metric_filter.scheduled_task_execution_failure.name
  namespace           = "LogMetrics"
  evaluation_periods  = 1
  period              = 60
  threshold           = 1
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alarm_scheduled_tasks_topic.arn]
}
