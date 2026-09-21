module "nft_seed_bucket" {
  source = "../../../modules/s3_bucket"

  bucket_name                        = "prsdb-seed-data-${var.environment_name}"
  access_log_bucket_name             = "prsdb-seed-data-access-logs-${var.environment_name}"
  kms_key_arn                        = aws_kms_key.nft_seed.arn
  noncurrent_version_expiration_days = 700
  access_s3_log_expiration_days      = 700
}

resource "aws_kms_key" "nft_seed" {
  description         = "Seed-data bucket encryption key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "nft_seed" {
  name          = "alias/seed-data-encryption-${var.environment_name}"
  target_key_id = aws_kms_key.nft_seed.key_id
}
