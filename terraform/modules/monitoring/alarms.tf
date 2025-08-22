resource "aws_cloudwatch_metric_alarm" "console_login" {
  alarm_name          = "console-login-${var.environment_name}"
  alarm_description   = "Someone has logged in to the AWS console"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  metric_name         = aws_cloudwatch_log_metric_filter.console_login.name
  evaluation_periods  = 1
  period              = 60
  threshold           = 1
  statistic           = "Sum"
  namespace           = "prsd/${var.environment_name}/security"

  alarm_actions = [
    aws_sns_topic.alarm_sns_topic.arn,
  ]
}


