# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "maintenance_page_bucket" {
  bucket = "${var.environment_name}-maintenance-page-bucket"
}

resource "aws_s3_bucket_public_access_block" "maintenance_page_bucket_public_access" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "maintenance_page" {
  for_each = fileset("..\\modules\\frontdoor\\maintenance_page", "**")

  bucket = aws_s3_bucket.maintenance_page_bucket.id
  key    = each.value
  source = "..\\modules\\frontdoor\\maintenance_page\\${each.value}"
  content_type = "text/html"
}

resource "aws_s3_object" "maintenance_page_index_file" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id
  key    = "maintenance"
  source = "..\\modules\\frontdoor\\maintenance_page\\index.html"
  content_type = "text/html"
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