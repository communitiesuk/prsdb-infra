resource "aws_cloudwatch_metric_alarm" "assume_role_with_saml" {
  alarm_name          = "assume-role-with-saml-${var.environment_name}"
  alarm_description   = "Someone has assumed an AWS role from AWS Console or from the command line using AWS Vault"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  metric_name         = aws_cloudwatch_log_metric_filter.assume_role_with_saml.name
  evaluation_periods  = 1
  period              = 60
  threshold           = 1
  statistic           = "Sum"
  namespace           = "prsd/${var.environment_name}/security"

  alarm_actions = [
    aws_sns_topic.alarm_sns_topic.arn,
  ]
}