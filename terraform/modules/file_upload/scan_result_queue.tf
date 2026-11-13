resource "aws_kms_key" "scan_result_queue" {
  description             = "${var.environment_name}-prsdb-scan-result-queue"
  enable_key_rotation     = true
  rotation_period_in_days = 180
}

resource "aws_kms_alias" "scan_result_queue" {
  target_key_id = aws_kms_key.scan_result_queue.key_id
  name          = "alias/${var.environment_name}-prsdb-scan-result-queue"
}

data "aws_iam_policy_document" "scan_result_queue_kms" {
  # EventBridge encrypts the scan results it sends to the scan result queue and its dead letter queue
  statement {
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.scan_result_queue.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Required to allow the KMS key to be managed after creation: https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-root-enable-iam
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = [aws_kms_key.scan_result_queue.arn]
  }
}

resource "aws_kms_key_policy" "scan_result_queue" {
  key_id = aws_kms_key.scan_result_queue.key_id
  policy = data.aws_iam_policy_document.scan_result_queue_kms.json
}

resource "aws_sqs_queue" "scan_result_dead_letter_queue" {
  name                              = "${var.environment_name}-prsdb-scan-result-dead-letter-queue"
  message_retention_seconds         = 1209600 # 14 days, the maximum
  kms_master_key_id                 = aws_kms_key.scan_result_queue.arn
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_sqs_queue" "scan_result_queue" {
  name                              = "${var.environment_name}-prsdb-scan-result-queue"
  visibility_timeout_seconds        = 60
  message_retention_seconds         = 345600 # 4 days
  kms_master_key_id                 = aws_kms_key.scan_result_queue.arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.scan_result_dead_letter_queue.arn
    maxReceiveCount     = 10
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "scan_result_dead_letter_queue" {
  queue_url = aws_sqs_queue.scan_result_dead_letter_queue.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.scan_result_queue.arn]
  })
}

# Enforce SSL connections, and allow only the scan complete rule to send scan results
data "aws_iam_policy_document" "scan_result_queue" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:*"]
    effect    = "Deny"
    resources = [aws_sqs_queue.scan_result_queue.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.scan_result_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.scan_complete_event_rule.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "scan_result_queue" {
  queue_url = aws_sqs_queue.scan_result_queue.id
  policy    = data.aws_iam_policy_document.scan_result_queue.json
}

# EventBridge sends scan results it fails to deliver to the scan result queue to the dead letter queue
data "aws_iam_policy_document" "scan_result_dead_letter_queue" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:*"]
    effect    = "Deny"
    resources = [aws_sqs_queue.scan_result_dead_letter_queue.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.scan_result_dead_letter_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.scan_complete_event_rule.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "scan_result_dead_letter_queue" {
  queue_url = aws_sqs_queue.scan_result_dead_letter_queue.id
  policy    = data.aws_iam_policy_document.scan_result_dead_letter_queue.json
}
