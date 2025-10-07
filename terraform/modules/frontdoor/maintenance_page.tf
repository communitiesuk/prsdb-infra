# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "maintenance_page_bucket" {
  bucket = "prsdb-maintenance-page-${var.environment_name}"
}

resource "aws_s3_bucket_public_access_block" "maintenance_page_bucket_public_access" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The index file needs to match the path name so it can be found
resource "aws_s3_object" "maintenance_page_index_file" {
  bucket       = aws_s3_bucket.maintenance_page_bucket.id
  key          = "maintenance"
  source       = "..\\modules\\frontdoor\\maintenance_page\\index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "maintenance_page_style_file" {
  bucket       = aws_s3_bucket.maintenance_page_bucket.id
  key          = "govuk-frontend-5.11.2.min.css"
  source       = "..\\modules\\frontdoor\\maintenance_page\\govuk-frontend-5.11.2.min.css"
  content_type = "text/css"
}

resource "aws_s3_object" "govuk_crest_svg" {
  bucket       = aws_s3_bucket.maintenance_page_bucket.id
  key          = "/assets/images/govuk-crest.svg"
  source       = "..\\modules\\frontdoor\\maintenance_page\\assets\\images\\govuk-crest.svg"
  content_type = "image/svg+xml"
}

resource "aws_s3_object" "gds_font_bold" {
  bucket       = aws_s3_bucket.maintenance_page_bucket.id
  key          = "/assets/fonts/bold-b542beb274-v2.woff2"
  source       = "..\\modules\\frontdoor\\maintenance_page\\assets\\fonts\\bold-b542beb274-v2.woff2"
  content_type = "font/woff2"
}

resource "aws_s3_object" "gds_font_light" {
  bucket       = aws_s3_bucket.maintenance_page_bucket.id
  key          = "/assets/fonts/light-94a07e06a1-v2.woff2"
  source       = "..\\modules\\frontdoor\\maintenance_page\\assets\\fonts\\light-94a07e06a1-v2.woff2"
  content_type = "font/woff2"
}

resource "aws_s3_bucket_policy" "maintenance_page" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id
  policy = data.aws_iam_policy_document.maintenance_page.json
}

data "aws_iam_policy_document" "maintenance_page" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.maintenance_oai.iam_arn]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.maintenance_page_bucket.arn}/*"]
  }
}

# KMS encryption is not supported for s3 buckets configured as a static website endpoint
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "maintenance_page_bucket" {
  bucket = aws_s3_bucket.maintenance_page_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "maintenance_page" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Access logs bucket
# tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "log_bucket" {
  bucket        = "prsdb-maintenance-page-access-logs-${var.environment_name}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_logging" "maintenance_page_bucket" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

# KMS encryption is not supported for logging target buckets
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id = "expire-old-logs"

    filter {}

    expiration {
      days = var.access_s3_log_expiration_days
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "allow_log_writes" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = data.aws_iam_policy_document.allow_log_writes.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "allow_log_writes" {
  source_policy_documents = [data.aws_iam_policy_document.allow_ssl_requests_only.json]
  statement {
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.log_bucket.arn}/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.maintenance_page_bucket.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Apply policy to enforce SSL connections.
data "aws_iam_policy_document" "allow_ssl_requests_only" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    effect = "Deny"

    resources = [
      aws_s3_bucket.log_bucket.arn,
      "${aws_s3_bucket.log_bucket.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}