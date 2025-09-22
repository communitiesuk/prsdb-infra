
resource "aws_s3_bucket" "maintenance_page_bucket" {
  bucket        = "${var.environment_name}-maintenance-page-bucket"
}

resource "aws_s3_bucket_public_access_block" "maintenance_page_bucket_public_access" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "maintenance_page_bucket_website" {
  bucket = aws_s3_bucket.maintenance_page_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_object" "maintenance_page" {
  for_each = fileset("maintenance_page", "**")

  bucket = aws_s3_bucket.maintenance_page_bucket.id
  key    = each.value
  source = "maintenance_page/${each.value}"
}
