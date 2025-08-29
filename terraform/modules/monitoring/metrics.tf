resource "aws_cloudwatch_log_metric_filter" "assume_role_with_saml" {
  log_group_name = module.cloudtrail_cloudwatch_group.name
  name           = "assume_role_with_saml_${var.environment_name}"
  pattern        = <<EOT
    {($.eventName = "AssumeRoleWithSAML")}
  EOT

  metric_transformation {
    name      = "assume_role_with_saml_${var.environment_name}"
    namespace = "prsd/${var.environment_name}/security"
    value     = "1"
  }
}