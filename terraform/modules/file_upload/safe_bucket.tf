module "safe_bucket" {
  source                             = "../s3_bucket"
  bucket_name                        = "prsdb-safe-${var.environment_name}"
  access_log_bucket_name             = "prsdb-safe-access-logs-${var.environment_name}"
  noncurrent_version_expiration_days = 700
  access_s3_log_expiration_days      = 700
  kms_key_arn                        = aws_kms_key.safe_bucket_encryption_key.arn
}

resource "aws_kms_key" "safe_bucket_encryption_key" {
  description         = "Safe bucket encryption key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "safe_bucket_encryption_key" {
  name          = "alias/safe-encryption-${var.environment_name}"
  target_key_id = aws_kms_key.safe_bucket_encryption_key.key_id
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "upload_to_safe" {
  statement {
    sid = "SafeS3"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${module.safe_bucket.bucket_arn}/*",
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
      aws_kms_key.safe_bucket_encryption_key.arn
    ]
  }
}

resource "aws_iam_policy" "upload_to_safe" {
  name   = "upload-to-safe"
  policy = data.aws_iam_policy_document.upload_to_safe.json
}

resource "aws_iam_role_policy_attachment" "ecs_safe_s3_attachment" {
  role       = data.aws_ecs_task_definition.webapp_task_definition.task_role_arn
  policy_arn = aws_iam_policy.upload_to_safe.arn
}