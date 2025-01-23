resource "aws_kms_key" "prsdb_webapp_secrets" {
  description         = "prsdb-webapp-secrets-${var.environment_name}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "prsdb_webapp_secrets" {
  target_key_id = aws_kms_key.prsdb_webapp_secrets.key_id
  name          = "alias/prsdb-webapp-secrets-${var.environment_name}"
}
