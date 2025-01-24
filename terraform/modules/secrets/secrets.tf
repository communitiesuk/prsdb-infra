resource "aws_secretsmanager_secret" "database_password" {
  name                    = "tf-${var.environment_name}-prsdb-database-password"
  description             = "Password for prsdb webapp database user"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.prsdb_webapp_secrets.arn
}

resource "random_password" "database_password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = random_password.database_password.result
}

resource "aws_secretsmanager_secret" "one_login_private_key" {
  name                    = "tf-${var.environment_name}-one-login-private-key"
  description             = "Private key for One Login"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.prsdb_webapp_secrets.arn
}

resource "aws_secretsmanager_secret" "notify_api_key" {
  name                    = "tf-${var.environment_name}-notify-api-key"
  description             = "API key for Notify"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.prsdb_webapp_secrets.arn
}

resource "aws_secretsmanager_secret" "os_places_api_key" {
  name                    = "tf-${var.environment_name}-os-places-api-key"
  description             = "API key for OS Places"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.prsdb_webapp_secrets.arn
}