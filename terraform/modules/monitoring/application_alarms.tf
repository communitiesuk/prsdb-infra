resource "aws_cloudwatch_metric_alarm" "virus_scan_failure" {
  alarm_name          = "${var.ecs_service_name}-virus-scan-failure"
  alarm_description   = "A virus scan has failed to be properly processed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = aws_cloudwatch_log_metric_filter.virus_scan_failure.name
  namespace           = "LogMetrics"
  evaluation_periods  = 1
  period              = 60
  threshold           = 1
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  alarm_actions = [
    aws_sns_topic.alarm_sns_topic.arn,
  ]
}
