data "aws_iam_policy_document" "consume_scan_result_queue" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.scan_result_queue.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.scan_result_queue.arn]
  }
}

resource "aws_iam_policy" "consume_scan_result_queue" {
  name   = "${var.environment_name}-consume-scan-result-queue"
  policy = data.aws_iam_policy_document.consume_scan_result_queue.json
}

resource "aws_iam_role_policy_attachment" "async_worker_consume_scan_result_queue" {
  role       = var.async_worker_ecs_task_role_name
  policy_arn = aws_iam_policy.consume_scan_result_queue.arn
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "process_scanned_files" {
  statement {
    sid = "ReadAndDeleteQuarantinedFiles"
    actions = [
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:DeleteObject",
    ]
    resources = ["${module.quarantine_bucket.bucket_arn}/*"]
  }

  statement {
    sid       = "DecryptQuarantinedFiles"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.quarantine_bucket_encryption_key.arn]
  }

  statement {
    sid = "CopyFilesToSafeBucket"
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]
    resources = ["${module.uploaded_files_bucket.bucket_arn}/*"]
  }

  statement {
    sid = "EncryptSafeFiles"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [aws_kms_key.uploaded_files_bucket_encryption_key.arn]
  }
}

resource "aws_iam_policy" "process_scanned_files" {
  name   = "${var.environment_name}-process-scanned-files"
  policy = data.aws_iam_policy_document.process_scanned_files.json
}

resource "aws_iam_role_policy_attachment" "async_worker_process_scanned_files" {
  role       = var.async_worker_ecs_task_role_name
  policy_arn = aws_iam_policy.process_scanned_files.arn
}
