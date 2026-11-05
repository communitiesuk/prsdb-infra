locals {
  non_critical_alarm_actions = var.non_critical_alarm_sns_topic_arn == null ? [] : [var.non_critical_alarm_sns_topic_arn]
  critical_alarm_actions     = var.critical_alarm_sns_topic_arn == null ? [] : [var.critical_alarm_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "email_dead_letter_queue_not_empty" {
  alarm_name          = "${var.environment_name}-prsdb-email-dead-letter-queue-not-empty"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.email_dead_letter_queue.name
  }

  alarm_description = <<-EOT
    One or more emails could not be sent after repeated retries.
    Check the email worker logs, fix the cause, then redrive ${aws_sqs_queue.email_dead_letter_queue.name}
    back to ${aws_sqs_queue.email_queue.name}.
  EOT
  alarm_actions     = local.non_critical_alarm_actions
  ok_actions        = local.non_critical_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "email_dead_letter_queue_many_failures" {
  alarm_name          = "${var.environment_name}-prsdb-email-dead-letter-queue-many-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.email_dead_letter_queue.name
  }

  alarm_description = <<-EOT
    10 or more emails could not be sent after repeated retries, so email sending may be failing altogether.
    Check the email worker logs, fix the cause, then redrive ${aws_sqs_queue.email_dead_letter_queue.name}
    back to ${aws_sqs_queue.email_queue.name}.
  EOT
  alarm_actions     = local.critical_alarm_actions
  ok_actions        = local.critical_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "email_queue_oldest_message_age" {
  alarm_name          = "${var.environment_name}-prsdb-email-queue-oldest-message-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 7200 # 2 hours, longer than the ~75 minute retry window
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.email_queue.name
  }

  alarm_description = <<-EOT
    An email has been waiting on ${aws_sqs_queue.email_queue.name} for over 2 hours.
    The email worker may be stopped or failing; messages are deleted after 4 days without reaching the dead letter queue.
  EOT
  alarm_actions     = local.critical_alarm_actions
  ok_actions        = local.critical_alarm_actions
}
