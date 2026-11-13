locals {
  non_critical_alarm_actions = var.non_critical_alarm_sns_topic_arn == null ? [] : [var.non_critical_alarm_sns_topic_arn]
  critical_alarm_actions     = var.critical_alarm_sns_topic_arn == null ? [] : [var.critical_alarm_sns_topic_arn]
  async_worker_log_group     = "${var.environment_name}-prsdb-async-worker"
}

resource "aws_cloudwatch_metric_alarm" "scan_result_dead_letter_queue_not_empty" {
  alarm_name          = "${var.environment_name}-prsdb-scan-result-dead-letter-queue-not-empty"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.scan_result_dead_letter_queue.name
  }

  alarm_description = <<-EOT
    One or more virus scan results could not be processed, so the scanned files are still quarantined.
    Messages with ERROR_CODE and ERROR_MESSAGE attributes could not be delivered to ${aws_sqs_queue.scan_result_queue.name} by EventBridge.
    For other messages, search the ${local.async_worker_log_group} log group for "Error processing message" to find the cause.
    Fix the cause, then redrive ${aws_sqs_queue.scan_result_dead_letter_queue.name} back to ${aws_sqs_queue.scan_result_queue.name}.
  EOT
  alarm_actions     = local.non_critical_alarm_actions
  ok_actions        = local.non_critical_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "scan_result_dead_letter_queue_many_failures" {
  alarm_name          = "${var.environment_name}-prsdb-scan-result-dead-letter-queue-many-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.scan_result_dead_letter_queue.name
  }

  alarm_description = <<-EOT
    10 or more virus scan results could not be processed, so virus scan processing may be failing altogether.
    Messages with ERROR_CODE and ERROR_MESSAGE attributes could not be delivered to ${aws_sqs_queue.scan_result_queue.name} by EventBridge.
    For other messages, search the ${local.async_worker_log_group} log group for "Error processing message" to find the cause.
    Fix the cause, then redrive ${aws_sqs_queue.scan_result_dead_letter_queue.name} back to ${aws_sqs_queue.scan_result_queue.name}.
  EOT
  alarm_actions     = local.critical_alarm_actions
  ok_actions        = local.critical_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "scan_result_queue_oldest_message_age" {
  alarm_name          = "${var.environment_name}-prsdb-scan-result-queue-oldest-message-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 7200 # 2 hours, longer than the ~75 minute retry window
  treat_missing_data  = "notBreaching"
  dimensions = {
    QueueName = aws_sqs_queue.scan_result_queue.name
  }

  alarm_description = <<-EOT
    A virus scan result has been waiting on ${aws_sqs_queue.scan_result_queue.name} for over 2 hours.
    The async worker may be stopped or failing (its logs are in the ${local.async_worker_log_group} log group);
    messages are deleted after 4 days without reaching the dead letter queue.
  EOT
  alarm_actions     = local.critical_alarm_actions
  ok_actions        = local.critical_alarm_actions
}
