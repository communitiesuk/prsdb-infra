#TODO: PRSD-1115 - add customer managed KMS key
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "redis_log_group" {
  name              = "${var.environment_name}-redis"
  retention_in_days = var.cloudwatch_log_expiration_days

  tags = {
    Application = var.environment_name
  }
}
