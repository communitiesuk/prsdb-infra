
resource "aws_cloudwatch_event_rule" "scan_complete_event_rule" {
  name        = "process-scan-complete-event-rule-${var.environment_name}"
  description = "Rule to process GuardDuty malware scan complete events"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Malware Protection Object Scan Result"]
  })
}

resource "aws_cloudwatch_event_target" "process_scan_complete_event_target" {
  target_id = "process-scan-complete-event-target-${var.environment_name}"
  rule      = aws_cloudwatch_event_rule.scan_complete_event_rule.name
  arn       = aws_sqs_queue.scan_result_queue.arn

  dead_letter_config {
    arn = aws_sqs_queue.scan_result_dead_letter_queue.arn
  }

  depends_on = [
    aws_sqs_queue_policy.scan_result_queue,
    aws_sqs_queue_policy.scan_result_dead_letter_queue,
    aws_kms_key_policy.scan_result_queue,
  ]
}