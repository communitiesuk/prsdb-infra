
module "scan_result_event_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = "prsdb-store_scan_complete-${var.environment_name}"
  access_log_bucket_name             = "prsdb-store_scan_complete-access-logs-${var.environment_name}"
  noncurrent_version_expiration_days = 700
  access_s3_log_expiration_days      = 700
  kms_key_arn                        = aws_kms_key.scan_result_event_bucket_encryption_key.arn
}

resource "aws_kms_key" "scan_result_event_bucket_encryption_key" {
  description         = "Scan result event bucket encryption key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "scan_result_event_bucket_encryption_key" {
  name          = "alias/scan_result_event-encryption-${var.environment_name}"
  target_key_id = aws_kms_key.scan_result_event_bucket_encryption_key.key_id
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "save_scan_result_event" {
  statement {
    sid = "save_scan_result_event"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${module.scan_result_event_bucket.bucket_arn}/*",
    ]
  }

  statement {
    sid    = "AllowKMSUsage"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [
      aws_kms_key.scan_result_event_bucket_encryption_key.arn
    ]
  }
}

resource "aws_iam_policy" "save_scan_result_event" {
  name   = "upload-to-scan_result_event"
  policy = data.aws_iam_policy_document.save_scan_result_event.json
}

resource "aws_iam_role_policy_attachment" "firehose_s3_attachment" {
  role       = aws_iam_role.kinesis_firehose_role.name
  policy_arn = aws_iam_policy.save_scan_result_event.arn
}
