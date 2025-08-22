# non-sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "alarm_sns_topic" {
  name         = "${var.environment_name}-alarm-sns-topic"
  display_name = "Notifications for cloudwatch alarms in ${var.environment_name} environment"
}

resource "aws_sns_topic_subscription" "alarm_email_subscription" {
  topic_arn = aws_sns_topic.alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = var.alarm_email_address
}