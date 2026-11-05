output "non_critical_alarm_sns_topic_arn" {
  value       = aws_sns_topic.non_critical_alarm_sns_topic.arn
  description = "ARN of the SNS topic for non-critical CloudWatch alarms"
}

output "critical_alarm_sns_topic_arn" {
  value       = aws_sns_topic.critical_alarm_sns_topic.arn
  description = "ARN of the SNS topic for critical CloudWatch alarms"
}
