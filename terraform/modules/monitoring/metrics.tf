resource "aws_cloudwatch_log_metric_filter" "console_login" {
  log_group_name = module.cloudtrail_cloudwatch_group.name
  name           = "console_login_${var.environment_name}"
  pattern        = <<EOT
    {($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success")}
  EOT

  metric_transformation {
    name      = "console_login_${var.environment_name}"
    namespace = "prsd/${var.environment_name}/security"
    value     = "1"
  }
}