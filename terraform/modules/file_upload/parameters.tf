resource "aws_ssm_parameter" "quarantine_bucket" {
  name  = "${var.environment_name}-prsdb-quarantine-bucket"
  type  = "String"
  value = module.quarantine_bucket.bucket
}
