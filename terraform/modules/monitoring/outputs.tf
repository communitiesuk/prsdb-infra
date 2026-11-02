output "non_critical_alarm_sns_topic_arn" {
  value       = aws_sns_topic.non_critical_alarm_sns_topic.arn
  description = "ARN of the SNS topic for non-critical CloudWatch alarms"
}
