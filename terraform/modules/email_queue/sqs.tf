resource "aws_sqs_queue" "email_dead_letter_queue" {
  name                              = "${var.environment_name}-prsdb-email-dead-letter-queue"
  message_retention_seconds         = 1209600 # 14 days, the maximum
  kms_master_key_id                 = aws_kms_key.email_queue.arn
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_sqs_queue" "email_queue" {
  name                              = "${var.environment_name}-prsdb-email-queue"
  visibility_timeout_seconds        = 60
  message_retention_seconds         = 345600 # 4 days
  kms_master_key_id                 = aws_kms_key.email_queue.arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_dead_letter_queue.arn
    maxReceiveCount     = 10
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "email_dead_letter_queue" {
  queue_url = aws_sqs_queue.email_dead_letter_queue.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.email_queue.arn]
  })
}
