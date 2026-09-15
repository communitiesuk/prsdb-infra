resource "aws_s3_bucket" "nft_seed" {
  bucket = "prsdb-seed-data-${var.environment_name}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "nft_seed" {
  bucket = aws_s3_bucket.nft_seed.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "nft_seed" {
  bucket = aws_s3_bucket.nft_seed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "nft_seed" {
  bucket = aws_s3_bucket.nft_seed.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "nft_seed" {
  bucket = aws_s3_bucket.nft_seed.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "nft_seed" {
  bucket = aws_s3_bucket.nft_seed.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 14
    }

    noncurrent_version_expiration {
      noncurrent_days = 700
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}

data "aws_iam_policy_document" "nft_seed_bucket" {
  statement {
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.nft_seed.arn,
      "${aws_s3_bucket.nft_seed.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "nft_seed" {
  bucket = aws_s3_bucket.nft_seed.id
  policy = data.aws_iam_policy_document.nft_seed_bucket.json
}
