resource "aws_cloudtrail" "main" {
  name                          = "prsd-cloudtrail-${var.environment_name}"
  s3_bucket_name                = module.s3_bucket.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  cloud_watch_logs_group_arn    = "${module.cloudtrail_cloudwatch_group.log_group_arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch_role.arn
}

module "cloudtrail_cloudwatch_group" {
  source = "../encrypted_log_group"

  log_group_name     = "prsd-cloudtrail-${var.environment_name}"
  log_retention_days = var.cloudwatch_log_expiration_days
}



