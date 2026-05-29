# non-sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "critical_alarm_sns_topic" {
  name         = "${var.environment_name}-critical-alarm-sns-topic"
  display_name = "Notifications for critical cloudwatch alarms in ${var.environment_name} environment"
}

resource "aws_sns_topic_subscription" "critical_alarm_email_subscription" {
  topic_arn = aws_sns_topic.critical_alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = var.critical_alarm_email_address
}

# non-sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "non_critical_alarm_sns_topic" {
  name         = "${var.environment_name}-non-critical-alarm-sns-topic"
  display_name = "Notifications for non-critical cloudwatch alarms in ${var.environment_name} environment"
}

resource "aws_sns_topic_subscription" "non_critical_alarm_email_subscription" {
  topic_arn = aws_sns_topic.non_critical_alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = var.non_critical_alarm_email_address
}

moved {
  from = aws_sns_topic.alarm_sns_topic
  to   = aws_sns_topic.critical_alarm_sns_topic
}

moved {
  from = aws_sns_topic_subscription.alarm_email_subscription
  to   = aws_sns_topic_subscription.critical_alarm_email_subscription
}